//
//  AdConfig.swift
//  Outdoor Day
//
//  Central place for AdMob IDs. Sample/test units ship until a dedicated
//  Outdoor Day AdMob app + banner unit are created in the shared publisher account.
//

import Foundation

enum AdConfig {
    /// Publisher: ca-app-pub-8223005482588566 (same as other LetsHang apps).
    /// Prefer Info.plist so production AdMob IDs can ship without a code change:
    /// `GADApplicationIdentifier` + `GADBannerAdUnitID`.
    private static let testApplicationID = "ca-app-pub-3940256099942544~1458002511"
    private static let testBannerUnitID = "ca-app-pub-3940256099942544/2934735716"

    static var applicationID: String {
        (Bundle.main.object(forInfoDictionaryKey: "GADApplicationIdentifier") as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .nilIfEmpty
            ?? testApplicationID
    }

    static var bannerUnitID: String {
        (Bundle.main.object(forInfoDictionaryKey: "GADBannerAdUnitID") as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .nilIfEmpty
            ?? testBannerUnitID
    }

    static var isUsingTestUnits: Bool {
        applicationID.contains("3940256099942544") || bannerUnitID.contains("3940256099942544")
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
