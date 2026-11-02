//
//  AdsService.swift
//  Outdoor Day
//

import Foundation
import GoogleMobileAds
import UIKit

@MainActor
final class AdsService {
    static let shared = AdsService()

    private(set) var isReady = false
    private var didStartSDK = false
    private var pendingActions: [() -> Void] = []

    private init() {}

    func beginStartup() {
        guard !didStartSDK else { return }
        didStartSDK = true

        #if DEBUG
        MobileAds.shared.requestConfiguration.testDeviceIdentifiers = ["Simulator"]
        #endif

        MobileAds.shared.start { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.isReady = true
                let actions = self.pendingActions
                self.pendingActions = []
                actions.forEach { $0() }
            }
        }
    }

    func whenReady(_ action: @escaping () -> Void) {
        if isReady {
            action()
        } else {
            pendingActions.append(action)
        }
    }

    static var topViewController: UIViewController? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let window = scenes.flatMap(\.windows).first(where: \.isKeyWindow) ?? scenes.flatMap(\.windows).first
        var top = window?.rootViewController
        while let presented = top?.presentedViewController {
            top = presented
        }
        return top
    }
}
