//
//  AdsService.swift
//  Outdoor Day
//

import AppTrackingTransparency
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

        // Ask for ATT before initializing the ads SDK (App Store requirement when tracking).
        Task { @MainActor in
            await self.requestTrackingIfNeeded()
            self.startMobileAds()
        }
    }

    private func requestTrackingIfNeeded() async {
        guard #available(iOS 14, *) else { return }
        // Slight delay so the permission dialog isn't under the launch screen.
        try? await Task.sleep(nanoseconds: 500_000_000)
        guard ATTrackingManager.trackingAuthorizationStatus == .notDetermined else { return }
        _ = await ATTrackingManager.requestTrackingAuthorization()
    }

    private func startMobileAds() {
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
