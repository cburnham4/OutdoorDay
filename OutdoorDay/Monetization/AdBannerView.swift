//
//  AdBannerView.swift
//  Outdoor Day
//

import GoogleMobileAds
import SwiftUI

struct AdBannerView: UIViewRepresentable {
    private let adUnitID = AdConfig.bannerUnitID
    private static let bannerHeight: CGFloat = 50

    func makeCoordinator() -> Coordinator {
        Coordinator(adUnitID: adUnitID)
    }

    func makeUIView(context: Context) -> UIView {
        let container = UIView()
        container.backgroundColor = .clear
        container.clipsToBounds = true

        let banner = BannerView(adSize: AdSizeBanner)
        banner.adUnitID = adUnitID
        banner.delegate = context.coordinator
        banner.translatesAutoresizingMaskIntoConstraints = false
        banner.clipsToBounds = true
        context.coordinator.bannerView = banner

        container.addSubview(banner)
        NSLayoutConstraint.activate([
            banner.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            banner.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            banner.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            banner.heightAnchor.constraint(equalToConstant: Self.bannerHeight)
        ])

        context.coordinator.scheduleLoad()
        return container
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.scheduleLoad()
    }

    final class Coordinator: NSObject, BannerViewDelegate {
        let adUnitID: String
        weak var bannerView: BannerView?
        private var hasLoaded = false

        init(adUnitID: String) {
            self.adUnitID = adUnitID
        }

        func scheduleLoad() {
            Task { @MainActor in
                AdsService.shared.whenReady { [weak self] in
                    guard let self, !self.hasLoaded, let banner = self.bannerView else { return }
                    banner.rootViewController = AdsService.topViewController
                    banner.load(Request())
                    self.hasLoaded = true
                }
            }
        }
    }
}
