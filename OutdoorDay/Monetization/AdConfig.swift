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
    /// Replace `applicationID` + `bannerUnitID` after creating the Outdoor Day AdMob app.
    static let applicationID = "ca-app-pub-3940256099942544~1458002511"
    static let bannerUnitID = "ca-app-pub-3940256099942544/2934735716"

    static var isUsingTestUnits: Bool {
        applicationID.contains("3940256099942544") || bannerUnitID.contains("3940256099942544")
    }
}
