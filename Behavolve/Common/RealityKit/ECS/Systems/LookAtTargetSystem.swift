//
//  LookAtTargetSystem.swift
//  Behavolve
//
//  Created by Michaël ATTAL on 30/01/2025.
//

import ARKit
import RealityKit
import SwiftUI

@MainActor public struct LookAtTargetSystem: System {
    @MainActor class DevicePoseShared {
        let devicePoseSafe: IsolatedValue<Transform>

        init() {
            self.devicePoseSafe = IsolatedValue<Transform>(initialValue: Transform())
        }
    }

    @MainActor static let shared = DevicePoseShared()

    @MainActor class IsolatedValue<Value> {
        var value: Value

        init(initialValue: Value) {
            self.value = initialValue
        }

        func setValue(_ value: Value) {
            self.value = value
        }
    }

    @MainActor static let query = EntityQuery(where: .has(LookAtTargetComponent.self))

    private let arkitSession = ARKitSession()
    private let worldTrackingProvider = WorldTrackingProvider()

    public init(scene: RealityKit.Scene) {
        setUpSession()
    }

    func setUpSession() {
        Task {
            do {
                if /* HandTrackingProvider.isSupported, */ WorldTrackingProvider.isSupported {
                    try await arkitSession.run([worldTrackingProvider])
                } else {
                    print("LookAtTargetSystem Hand tracking not supported")
                }
            } catch {
                print("LookAtTargetSystem setUpSession error: \(error)")
            }
            await monitorUpdateDevicePosition()
        }
    }

    public func update(context: SceneUpdateContext) {
        let devicePosition = LookAtTargetSystem.shared.devicePoseSafe.value.translation
        for entity in context.entities(matching: Self.query, updatingSystemWhen: .rendering) {
            guard let lookAtTargetComponent = entity.components[LookAtTargetComponent.self] else {
                preconditionFailure("entity should have a LookAtTargetComponent")
                continue
            }

            guard let targetPosition = switch lookAtTargetComponent.target {
            case .device: devicePosition
            case .world(let position): position
            } else {
                continue
            }

            entity.look(at: lookAtTargetComponent.targetCorrection?(entity.position(relativeTo: nil), targetPosition) ?? targetPosition,
                        from: entity.position(relativeTo: nil),
                        upVector: .dy(1),
                        relativeTo: nil,
                        forward: .positiveZ)
        }
    }

    private func devicePose() -> Transform? {
        guard case .running = worldTrackingProvider.state,
              let deviceAnchor = worldTrackingProvider.queryDeviceAnchor(atTimestamp: CACurrentMediaTime())
        else {
            return nil
        }

        return Transform(matrix: deviceAnchor.originFromAnchorTransform)
    }

    private func monitorUpdateDevicePosition() async {
        while worldTrackingProvider.state != .stopped {
            try? await Task.sleep(for: .seconds(1.0 / 60))
            if let pose = devicePose() {
                LookAtTargetSystem.shared.devicePoseSafe.setValue(pose)
            }
        }
        print("LookAtTargetSystem monitorUpdateDevicePosition stopped")
    }
}

#Preview {
    RealityView { content, attachments in
        LookAtTargetSystem.registerSystem()
        LookAtTargetComponent.registerComponent()

        if let entity = attachments.entity(for: "previewTag") {
            let lookAtUserComponent = LookAtTargetComponent(target: .device)
            entity.components[LookAtTargetComponent.self] = lookAtUserComponent

            content.add(entity)
        }
    } attachments: {
        Attachment(id: "previewTag") {
            Text("Preview")
                .font(.system(size: 100))
                .background(.pink)
        }
    }
    .previewLayout(.sizeThatFits)
}
