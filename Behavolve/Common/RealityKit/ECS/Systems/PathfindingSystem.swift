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
    private let cell: Float = 0.25 // grid resolution (m)

    private var blocked = Set<Grid>() // all currently occupied grid cells
    private var perAnchorCells = [UUID: Set<Grid>]() // cache for precise removal

    private let meshProvider = AppState.sceneReconstruction
    private var arSession: ARKitSession? // kept alive for the whole system

    private static let query = EntityQuery(where: .has(MoveToComponent.self))

    required init(scene: Scene) {
#if !targetEnvironment(simulator)
        guard SceneReconstructionProvider.isSupported else {
            print("PathfindingSystem: SceneReconstructionProvider is not supported on this device.")
            return
        }

        arSession = AppState.arkitSession
        Task { await listenToMesh() }

#else
        print("PathfindingSystem: Running in simulator, mesh listening is disabled.")
#endif
    }

    func update(context: SceneUpdateContext) {
        guard arSession != nil else { return }

        for entity in context.scene.performQuery(Self.query) {
            guard var move = entity.components[MoveToComponent.self],
                  move.strategy == .pathfinding,
                  move.path.isEmpty
            else { continue }

            guard
                let startG = grid(from: entity.position(relativeTo: nil)),
                let goalG = grid(from: move.destination)
            else { continue } // skip if positions are invalid

            if let gPath = aStar(from: startG, to: goalG) {
                move.path = gPath.map { world(from: $0, y: entity.position(relativeTo: nil).y) }
                print("PathfindingSystem: Path found for entity \(entity.id) with \(move.path.count) waypoints.")
            } else {
                print("PathfindingSystem: No path found for entity \(entity.id) from \(startG) to \(goalG). Fallback to direct.")
                move.strategy = .direct
            }
            entity.components.set(move)
        }
    }

    private func listenToMesh() async {
        do {
            try await arSession?.run([meshProvider])
            print("PathfindingSystem: ARKitSession running with SceneReconstructionProvider.")
        } catch {
            print("PathfindingSystem: Failed to run ARKitSession – \(error)")
            return
        }

        for await update in meshProvider.anchorUpdates {
            print("PathfindingSystem: Received mesh anchor update: \(update.event) for anchor \(update.anchor.id)")
            switch update.event {
            case .added:
                await integrate(update.anchor)
            case .updated:
                await erase(update.anchor) // remove old footprint
                await integrate(update.anchor)
            case .removed:
                await erase(update.anchor)
            @unknown default:
                print("PathfindingSystem: Unknown mesh anchor update event.")
            }
        }
        print("PathfindingSystem: Mesh anchor update stream finished.")
    }

    /// Adds the anchor’s occupied cells to `blocked`.
    private func integrate(_ anchor: MeshAnchor) async {
        let cells = await cells(for: anchor)
        blocked.formUnion(cells)
        perAnchorCells[anchor.id] = cells
        print("PathfindingSystem: Integrated anchor \(anchor.id). Total blocked: \(blocked.count)")
    }

    /// Removes the anchor’s occupied cells from `blocked`.
    private func erase(_ anchor: MeshAnchor) async {
        guard let cells = perAnchorCells[anchor.id] else { return }
        blocked.subtract(cells)
        perAnchorCells[anchor.id] = nil
        print("PathfindingSystem: Erased anchor \(anchor.id). Total blocked: \(blocked.count)")
    }

    /// Builds the set of grid cells occupied by the given anchor.
    private func cells(for anchor: MeshAnchor) async -> Set<Grid> {
        await withCheckedContinuation { cont in
            // Heavy mesh extraction off the main actor
            Task.detached {
                var out = Set<Grid>()
                if let meshResource = try? await MeshResource(from: anchor) {
                    let transform = anchor.originFromAnchorTransform
                    for model in await meshResource.contents.models {
                        for part in model.parts {
                            for localPos in part.positions {
                                let worldPos = (transform * SIMD4<Float>(localPos, 1)).xyz
                                if let g = await self.grid(from: worldPos) { out.insert(g) }
                            }
                        }
                    }
                } else {
                    print("PathfindingSystem: Failed to extract mesh from anchor \(anchor.id)")
                }
                cont.resume(returning: out)
            }
        }
    }

    // MARK: A*

    private struct Grid: Hashable, CustomStringConvertible {
        let x: Int, z: Int
        var description: String { "(\(x), \(z))" }
    }

    /// Converts a world-space position to grid coordinates. Returns `nil` if the position is not finite.
    private func grid(from p: SIMD3<Float>) -> Grid? {
        guard p.x.isFinite, p.z.isFinite else { return nil }
        return Grid(x: Int(round(p.x / cell)), z: Int(round(p.z / cell)))
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

        func heuristic(_ a: Grid, _ b: Grid) -> Float {
            Float(abs(a.x - b.x) + abs(a.z - b.z))
        }

        var open = Heap<Node>()
        var came = [Grid: Grid]()
        var gScore = [start: Float(0)]

        open.push(Node(g: 0, h: heuristic(start, goal), grid: start))

        let dirs = [
            Grid(x: 1, z: 0), Grid(x: -1, z: 0),
            Grid(x: 0, z: 1), Grid(x: 0, z: -1),
            Grid(x: 1, z: 1), Grid(x: -1, z: -1),
            Grid(x: 1, z: -1), Grid(x: -1, z: 1)
        ]

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

                let cost: Float = (d.x != 0 && d.z != 0) ? 1.41421356 : 1.0
                let tentative = (gScore[current.grid] ?? .infinity) + cost
                if tentative < (gScore[n] ?? .infinity) {
                    came[n] = current.grid
                    gScore[n] = tentative
                    open.push(Node(g: tentative, h: heuristic(n, goal), grid: n))
                }
            }
        }
        return nil
    }
}
