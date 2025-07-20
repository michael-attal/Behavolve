//
//  RealityKitHelper+CollisionGroupMask.swift
//  Behavolve
//
//  Created by Michaël ATTAL on 25/06/2025.
//

import RealityKit

extension RealityKitHelper {
    // Define group identifiers using bit masks
    enum CollisionGroupType: CaseIterable {
        case `default`
        case bee
        case beehive
        case halo
        case therapist
        case waterBottle
        case all

        var bitMask: UInt32 {
            switch self {
            case .default: return 1 << 0 // 000001
            case .bee: return 1 << 1 // 000010
            case .beehive: return 1 << 2 // 000100
            case .halo: return 1 << 3 // 001000
            case .therapist: return 1 << 4 // 010000
            case .waterBottle: return 1 << 5 // 100000
            case .all: return UInt32.max
            }
        }
    }

    // Format a UInt32 bitmask as a padded binary string
    private static func formatBinary(_ value: UInt32, width: Int = 6) -> String {
        let binary = String(value, radix: 2)
        let padded = String(repeating: "0", count: max(0, width - binary.count)) + binary
        return "0b" + padded
    }

    // Describes the active flags in a bitmask in readable form
    static func describeMask(from rawMask: UInt32) -> String {
        let allCases = CollisionGroupType.allCases.filter { $0 != .all }
        let included = allCases.filter { rawMask & $0.bitMask != 0 }
        let names = included.map { ".\($0)" }.joined(separator: ", ")
        return "[\(names)] [bitMask: \(formatBinary(rawMask))]"
    }

    @MainActor
    static func updateCollisionFilter(
        for entity: Entity,
        groupType: CollisionGroupType,
        maskTypes: [CollisionGroupType]? = nil,
        subtracting: CollisionGroupType? = nil
    ) {
        precondition(groupType != .all, "❌ CollisionFilter group cannot be `.all`. Use a specific group (e.g. .bee, .halo...)")

        // Build the initial mask
        let baseMask: CollisionGroup = {
            guard let types = maskTypes, !types.isEmpty else {
                return .all
            }
            let maskValue = types.reduce(0) { $0 | $1.bitMask }
            return CollisionGroup(rawValue: maskValue)
        }()

        // Apply subtraction if needed
        let finalMask: CollisionGroup = {
            guard let subtract = subtracting else { return baseMask }
            return baseMask.subtracting(CollisionGroup(rawValue: subtract.bitMask))
        }()

        // Construct the new filter
        let filter = CollisionFilter(
            group: CollisionGroup(rawValue: groupType.bitMask),
            mask: finalMask
        )

        let groupBitmask = groupType.bitMask
        let maskBitmask = finalMask.rawValue
        let groupName = "\(groupType)"
        let maskDescription = describeMask(from: maskBitmask)

        if var collision = entity.components[CollisionComponent.self] {
            collision.filter = filter
            entity.components.set(collision)
            print("✅ Updated CollisionComponent → Group: \(groupName) [bitMask: \(formatBinary(groupBitmask))], Mask: \(maskDescription)")
        } else {
            // Generate shapes and create component if missing
            entity.generateCollisionShapes(recursive: true)
            guard let shapeComponent = entity.findFirstCollisionComponent() else {
                print("❌ Failed to generate collision shapes for entity")
                return
            }

            let newCollision = CollisionComponent(
                shapes: shapeComponent.shapes,
                mode: .default,
                filter: filter
            )
            entity.components.set(newCollision)
            print("⚠️ Created CollisionComponent → Group: \(groupName) [bitMask: \(formatBinary(groupBitmask))], Mask: \(maskDescription)")
        }
    }
}
