//
//  AppState.swift
//  Behavolve
//
//  Created by Michaël ATTAL on 28/10/2024.
//

import ARKit
import Foundation
import OpenAI
import RealityKit

enum ImmersiveViewAvailable: String {
    case none
    case bee
    case snake

    static func getAllImmersiveViews() -> [ImmersiveViewAvailable] {
        return [.bee, .snake]
    }
}

/// Maintains app-wide state
@MainActor
@Observable
class AppState {
    static let isDevelopmentMode = false
    let beeSceneState = BeeSceneState()

    var openAI = OpenAI(configuration: OpenAI.Configuration(token: YOUR_OPENAI_TOKEN_HERE, organizationIdentifier: YOUR_OPENAI_ORGANIZATION_ID_HERE, timeoutInterval: 86_400.0))

    let MenuWindowID = "MenuWindow"
    let immersiveSpaceID = "ImmersiveSpace"

    enum ImmersiveSpaceState {
        case closed
        case inTransition
        case open
    }

    var immersiveSpaceState = ImmersiveSpaceState.closed

    var currentImmersiveView: ImmersiveViewAvailable = .none

    var handTracking = HandTrackingProvider()
    var planeDetection = PlaneDetectionProvider(alignments: [.horizontal]) // Used to detect ceil
    var wolrdTracking = WorldTrackingProvider()

    func didLeaveImmersiveSpace() {
        arkitSession.stop()
    }

    // MARK: - ARKit state

    var arkitSession = ARKitSession()
    var providersStoppedWithError = false
    var worldSensingAuthorizationStatus = ARKitSession.AuthorizationStatus.notDetermined
    var handTrackingAuthorizationStatus = ARKitSession.AuthorizationStatus.notDetermined
    var sceneReconstruction = SceneReconstructionProvider()

    var allRequiredAuthorizationsAreGranted: Bool {
        worldSensingAuthorizationStatus == .allowed && handTrackingAuthorizationStatus == .allowed
    }

    var allRequiredProvidersAreSupported: Bool {
        WorldTrackingProvider.isSupported && HandTrackingProvider.isSupported && PlaneDetectionProvider.isSupported
    }

    var canEnterImmersiveSpace: Bool {
        allRequiredAuthorizationsAreGranted && allRequiredProvidersAreSupported
    }

    func requestHandTrackingAuthorization() async {
        let authorizationResult = await arkitSession.requestAuthorization(for: [.handTracking])
        handTrackingAuthorizationStatus = authorizationResult[.handTracking]!
    }

    func queryHandTrackingAuthorization() async {
        let authorizationResult = await arkitSession.queryAuthorization(for: [.handTracking])
        handTrackingAuthorizationStatus = authorizationResult[.handTracking]!
    }

    func requestWorldSensingAuthorization() async {
        let authorizationResult = await arkitSession.requestAuthorization(for: [.worldSensing])
        worldSensingAuthorizationStatus = authorizationResult[.worldSensing]!
    }

    func queryWorldSensingAuthorization() async {
        let authorizationResult = await arkitSession.queryAuthorization(for: [.worldSensing])
        worldSensingAuthorizationStatus = authorizationResult[.worldSensing]!
    }

    func monitorSessionEvents() async {
        for await event in arkitSession.events {
            switch event {
            case .dataProviderStateChanged(_, let newState, let error):
                switch newState {
                case .initialized:
                    break
                case .running:
                    break
                case .paused:
                    break
                case .stopped:
                    if let error {
                        print("An error occurred: \(error)")
                        providersStoppedWithError = true
                    }
                @unknown default:
                    break
                }
            case .authorizationChanged(let type, let status):
                print("Authorization type \(type) changed to \(status)")
                if type == .worldSensing {
                    worldSensingAuthorizationStatus = status
                }
                else if type == .handTracking {
                    handTrackingAuthorizationStatus = status
                }
            default:
                print("An unknown event occured \(event)")
            }
        }
    }
}
