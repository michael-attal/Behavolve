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

    // entities that need a path
    private static let query = EntityQuery(where: .has(MoveToComponent.self))

    required init(scene: Scene) {
#if !targetEnvironment(simulator)
        guard SceneReconstructionProvider.isSupported else { return }
        meshProvider = SceneReconstructionProvider()
        Task { await listenToMesh() }
#endif
    }

    func update(context: SceneUpdateContext) {
        for entity in context.scene.performQuery(Self.query) {
            guard var move = entity.components[MoveToComponent.self],
                  move.strategy == .pathfinding,
                  move.path.isEmpty // not already calculated
            else { continue }

            let startG = grid(from: entity.position(relativeTo: nil))
            let goalG = grid(from: move.destination)

            if let gPath = aStar(from: startG, to: goalG) {
                move.path = gPath.map { world(from: $0, y: entity.position(relativeTo: nil).y) }
            } else {
                move.strategy = .direct // fallback
            }
            entity.components.set(move)
        }
    }

    // Scene-reconstruction
    private func listenToMesh() async {
        guard let provider = meshProvider else { return }
        let session = ARKitSession()
        try? await session.run([provider])

        for await update in provider.anchorUpdates {
            let anchor = update.anchor
            switch update.event {
            case .added, .updated: integrate(anchor)
            case .removed: erase(anchor)
            @unknown default: break
            }
        }
    }

    private func integrate(_ anchor: MeshAnchor) {
        let tr = anchor.originFromAnchorTransform
        let vertices = anchor.geometry.vertices
        let count = vertices.count
        let stride = vertices.stride
        let basePtr = vertices.buffer.contents() // UnsafeMutableRawPointer

        // CHANGE: read raw memory since GeometrySource has no helper API.
        for i in 0..<count {
            let ptr = basePtr.advanced(by: i * stride)
            let local = ptr.assumingMemoryBound(to: SIMD3<Float>.self).pointee
            let world4 = tr * SIMD4<Float>(local, 1)
            blocked.insert(grid(from: world4.xyz))
        }
    }

    private func erase(_ anchor: MeshAnchor) {
        let tr = anchor.originFromAnchorTransform
        let vertices = anchor.geometry.vertices
        let count = vertices.count
        let stride = vertices.stride
        let basePtr = vertices.buffer.contents()

        // CHANGE: same raw access for removal
        for i in 0..<count {
            let ptr = basePtr.advanced(by: i * stride)
            let local = ptr.assumingMemoryBound(to: SIMD3<Float>.self).pointee
            let world4 = tr * SIMD4<Float>(local, 1)
            blocked.remove(grid(from: world4.xyz))
        }
    }

    // MARK: A*

    private struct Grid: Hashable {
        let x: Int, z: Int
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
                if blocked.contains(n) { continue }
                let tentative = (gScore[current.grid] ?? .infinity) + 1
                if tentative < (gScore[n] ?? .infinity) {
                    came[n] = current.grid
                    gScore[n] = tentative
                    open.push(Node(g: tentative, h: h(n, goal), grid: n))
                }
            }
        }
        return nil
    }
}
