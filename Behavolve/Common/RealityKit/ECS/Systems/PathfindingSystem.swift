//
//  PathfindingSystem.swift
//  Behavolve
//
//  Created by Michaël ATTAL on 24/04/2025.
//

import ARKit
import Foundation
import Metal
import RealityKit

// binary heap
private struct Heap<E: Comparable> {
    private var items: [E] = []
    mutating func push(_ v: E) { items.append(v); siftUp(from: items.count - 1) }
    mutating func pop() -> E? {
        guard !items.isEmpty else { return nil }
        items.swapAt(0, items.count - 1)
        let out = items.removeLast()
        siftDown(from: 0)
        return out
    }

    private mutating func siftUp(from i: Int) {
        var child = i
        while child > 0 {
            let parent = (child - 1) / 2
            if items[child] < items[parent] { items.swapAt(child, parent); child = parent }
            else { break }
        }
    }

    private mutating func siftDown(from i: Int) {
        var p = i
        while true {
            let l = 2 * p + 1, r = l + 1
            var smallest = p
            if l < items.count, items[l] < items[smallest] { smallest = l }
            if r < items.count, items[r] < items[smallest] { smallest = r }
            if smallest == p { break }
            items.swapAt(p, smallest); p = smallest
        }
    }
}

@MainActor
final class PathfindingSystem: System {
    private let cell: Float = 0.10 // grid resolution (m)

    private var blocked = Set<Grid>() // occupied by the mesh
    private var meshProvider: SceneReconstructionProvider?
    private var activeMeshAnchors: [UUID: MeshAnchor] = [:]

    // entities that need a path
    private static let query = EntityQuery(where: .has(MoveToComponent.self))

    required init(scene: Scene) {
#if !targetEnvironment(simulator)
        guard SceneReconstructionProvider.isSupported else {
            print("PathfindingSystem: SceneReconstructionProvider is not supported on this device.")
            return
        }
        meshProvider = SceneReconstructionProvider()
        Task {
            print("PathfindingSystem: Starting to listen to mesh updates.")
            await listenToMesh()
        }
#else
        print("PathfindingSystem: Running in simulator, mesh listening is disabled.")
#endif
    }

    func update(context: SceneUpdateContext) {
        guard meshProvider != nil else { return }

        for entity in context.scene.performQuery(Self.query) {
            guard var move = entity.components[MoveToComponent.self],
                  move.strategy == .pathfinding,
                  move.path.isEmpty // not already calculated
            else { continue }

            let startG = grid(from: entity.position(relativeTo: nil))
            let goalG = grid(from: move.destination)

            if let gPath = aStar(from: startG, to: goalG) {
                move.path = gPath.map { world(from: $0, y: entity.position(relativeTo: nil).y) }
                print("PathfindingSystem: Path found for entity \(entity.id) with \(move.path.count) waypoints.")
            } else {
                print("PathfindingSystem: No path found for entity \(entity.id) from \(startG) to \(goalG). Fallback to direct.")
                move.strategy = .direct // fallback
            }
            entity.components.set(move)
        }
    }

    // Scene-reconstruction
    private func listenToMesh() async {
        guard let provider = meshProvider else {
            print("PathfindingSystem: MeshProvider is nil in listenToMesh.")
            return
        }
        let session = ARKitSession() // This session is local to this function's scope
        // It should ideally be a member of the class or passed in if managed externally.
        // For now, let's assume this is fine for SceneReconstructionProvider.
        do {
            try await session.run([provider])
            print("PathfindingSystem: ARKitSession running with SceneReconstructionProvider.")
        } catch {
            print("PathfindingSystem: Failed to run ARKitSession with SceneReconstructionProvider: \(error)")
            return
        }

        for await update in provider.anchorUpdates {
            print("PathfindingSystem: Received mesh anchor update: \(update.event) for anchor \(update.anchor.id)")
            let anchor = update.anchor
            switch update.event {
            case .added, .updated:
                if update.event == .updated, activeMeshAnchors[anchor.id] != nil {
                    await erase(anchor) // Erase based on the old (stored) anchor data if needed, or simply clear and re-add.
                    // For simplicity here, we will clear based on the new anchor's geometry transformed by its old transform if available.
                    // Or, even simpler: just re-process. A* grid cells are small, so over-marking is less bad than under-marking.
                    // Let's ensure `erase` can handle the current anchor if it's an update.
                    // The most robust way is to store the anchor and use its geometry for erase.
                }
                await integrate(anchor)
                activeMeshAnchors[anchor.id] = anchor // Store the latest version
            case .removed:
                await erase(anchor)
                activeMeshAnchors.removeValue(forKey: anchor.id)
            @unknown default:
                print("PathfindingSystem: Unknown mesh anchor update event.")
            }
        }
        print("PathfindingSystem: Mesh anchor update stream finished.")
    }

    private func integrate(_ anchor: MeshAnchor) async {
        guard let meshResource = try? await MeshResource(from: anchor) else {
            print("PathfindingSystem: Failed to get MeshResource from anchor \(anchor.id) in integrate.")
            return
        }
        let transform = anchor.originFromAnchorTransform

        for model in meshResource.contents.models {
            for part in model.parts {
                // The positions are in the anchor's local coordinate space.
                for localPosition in part.positions {
                    let worldPosition = (transform * SIMD4<Float>(localPosition, 1)).xyz
                    blocked.insert(grid(from: worldPosition))
                }
            }
        }
        print("PathfindingSystem: Integrated anchor \(anchor.id). Blocked cell count: \(blocked.count)")
    }

    private func erase(_ anchor: MeshAnchor) async {
        // To accurately erase, we need the geometry of the anchor *as it was when added*.
        // Using the current anchor's geometry is an approximation if it has changed significantly.
        // If we stored the exact set of Grid cells per anchor, removal would be precise.
        // For now, using the provided anchor's geometry for removal.
        guard let meshResource = try? await MeshResource(from: anchor) else {
            print("PathfindingSystem: Failed to get MeshResource from anchor \(anchor.id) in erase.")
            return
        }
        let transform = anchor.originFromAnchorTransform

        for model in meshResource.contents.models {
            for part in model.parts {
                for localPosition in part.positions {
                    let worldPosition = (transform * SIMD4<Float>(localPosition, 1)).xyz
                    blocked.remove(grid(from: worldPosition))
                }
            }
        }
        print("PathfindingSystem: Erased anchor \(anchor.id). Blocked cell count: \(blocked.count)")
    }

    // MARK: A*

    private struct Grid: Hashable, CustomStringConvertible {
        let x: Int, z: Int
        var description: String { "(\(x), \(z))" }
    }

    private func grid(from p: SIMD3<Float>) -> Grid {
        .init(x: Int(round(p.x / cell)), z: Int(round(p.z / cell)))
    }

    private func world(from g: Grid, y: Float) -> SIMD3<Float> {
        SIMD3(Float(g.x) * cell, y, Float(g.z) * cell)
    }

    private func aStar(from start: Grid, to goal: Grid) -> [Grid]? {
        struct Node: Comparable {
            let g: Float, h: Float, grid: Grid
            var f: Float { g + h }
            static func < (lhs: Node, rhs: Node) -> Bool { lhs.f < rhs.f }
        }

        func h(_ a: Grid, _ b: Grid) -> Float {
            Float(abs(a.x - b.x) + abs(a.z - b.z)) // Manhattan
        }

        var open = Heap<Node>()
        var came = [Grid: Grid]()
        var gScore: [Grid: Float] = [:]
        gScore[start] = 0

        open.push(Node(g: 0, h: h(start, goal), grid: start))

        let dirs = [Grid(x: 1, z: 0), Grid(x: -1, z: 0),
                    Grid(x: 0, z: 1), Grid(x: 0, z: -1),
                    Grid(x: 1, z: 1), Grid(x: -1, z: -1),
                    Grid(x: 1, z: -1), Grid(x: -1, z: 1)]

        while let current = open.pop() {
            if current.grid == goal {
                // reconstruction
                var path = [current.grid]
                var cur = current.grid
                while let p = came[cur] {
                    path.append(p); cur = p
                }
                return path.reversed()
            }

            for d in dirs {
                let n = Grid(x: current.grid.x + d.x, z: current.grid.z + d.z)
                if blocked.contains(n) {
                    print("PathfindingSystem: A* neighbor \(n) is blocked.")
                    continue
                }
                // For simplicity, we'll keep 1 for now, assuming grid cells are coarse enough.
                // Or, more accurately, adjust cost based on `d`.
                let cost: Float = (d.x != 0 && d.z != 0) ? 1.41421356 : 1.0 // sqrt(2) for diagonals

                let tentative = (gScore[current.grid] ?? .infinity) + cost
                if tentative < (gScore[n] ?? .infinity) {
                    came[n] = current.grid
                    gScore[n] = tentative
                    open.push(Node(g: tentative, h: h(n, goal), grid: n))
                }
            }
        }
        print("PathfindingSystem: A* failed to find a path from \(start) to \(goal).")
        return nil
    }
}
