//
//  DayPlannerModel.swift
//  Outdoor Day
//

import CoreLocation
import Foundation

@MainActor
final class DayPlannerModel: ObservableObject {
    @Published var conditions: DayConditions?
    @Published var outlook: [OutlookDay] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var placeName: String?

    let location = LocationManager()
    private let client = OpenMeteoClient()

    func start() {
        location.request()
    }

    func refresh() async {
        if let coordinate = location.coordinate {
            await load(coordinate: coordinate)
            return
        }
        location.request()
        for _ in 0..<20 {
            if let coordinate = location.coordinate {
                await load(coordinate: coordinate)
                return
            }
            try? await Task.sleep(nanoseconds: 250_000_000)
        }
        if location.authorizationDenied {
            errorMessage = location.statusMessage
        } else {
            errorMessage = location.statusMessage ?? "Waiting for location…"
        }
    }

    func load(coordinate: CLLocationCoordinate2D) async {
        isLoading = true
        errorMessage = nil
        placeName = location.placeName
        defer { isLoading = false }
        do {
            let today = try await client.fetchConditions(
                latitude: coordinate.latitude,
                longitude: coordinate.longitude
            )
            conditions = today
            placeName = location.placeName
            let todayPollen = (label: today.pollenLabel, value: today.pollenGrains)
            outlook = (try? await client.fetchOutlook(
                latitude: coordinate.latitude,
                longitude: coordinate.longitude,
                todayPollen: todayPollen
            )) ?? []
        } catch {
            errorMessage = "Couldn’t load outdoor conditions. Pull to try again."
        }
    }

    func onLocationMaybeUpdated() async {
        guard let coordinate = location.coordinate else { return }
        if conditions == nil || !isLoading {
            await load(coordinate: coordinate)
        }
    }
}
