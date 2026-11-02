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

        // Ask for ATT before initializing the ads SDK (App Store requirement when tracking).
        Task { @MainActor in
            // Brief yield so simulator `defaults write` / container prefs are visible
            // before the first UserDefaults read (screenshot tooling uses skipATT).
            try? await Task.sleep(nanoseconds: 150_000_000)
            UserDefaults.standard.synchronize()
            #if DEBUG
            Self.writeScreenshotDebugLog()
            #endif
            // Screenshot tooling: `defaults write us.letshang.outdoor-day skipATT -bool YES`
            // Do not touch MobileAds / BannerView at all when skipping — any GMA access can present ATT.
            if Self.shouldSkipATT {
                self.pendingActions = []
                return
            }
            #if DEBUG
            MobileAds.shared.requestConfiguration.testDeviceIdentifiers = ["Simulator"]
            #endif
            await self.requestTrackingIfNeeded()
            self.startMobileAds()
        }
    }

    private static var shouldSkipATT: Bool {
        ProcessInfo.processInfo.arguments.contains("-skipATT")
            || ProcessInfo.processInfo.environment["SKIP_ATT"] == "1"
            || UserDefaults.standard.bool(forKey: "skipATT")
    }

    #if DEBUG
    private static func writeScreenshotDebugLog() {
        let defaults = UserDefaults.standard
        let line = [
            "skipATT_bool=\(defaults.bool(forKey: "skipATT"))",
            "skipATT_obj=\(String(describing: defaults.object(forKey: "skipATT")))",
            "forcePremium=\(defaults.bool(forKey: "forcePremium"))",
            "args=\(ProcessInfo.processInfo.arguments)",
            "bundle=\(Bundle.main.bundleIdentifier ?? "nil")"
        ].joined(separator: " ")
        guard let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        try? (line + "\n").write(to: docs.appendingPathComponent("screenshot-debug.txt"), atomically: true, encoding: .utf8)
    }
    #endif

    private func requestTrackingIfNeeded() async {
        guard #available(iOS 14, *) else { return }
        if Self.shouldSkipATT { return }
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
