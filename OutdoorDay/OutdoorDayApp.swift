//
//  OutdoorDayApp.swift
//  Outdoor Day
//
//  One-screen UV / pollen / air-quality “should I go outside?” planner.
//

import SwiftUI

@main
struct OutdoorDayApp: App {
    @StateObject private var purchases = PurchaseManager.shared
    @StateObject private var dayModel = DayPlannerModel()

    init() {
        AdsService.shared.beginStartup()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(purchases)
                .environmentObject(dayModel)
        }
    }
}
