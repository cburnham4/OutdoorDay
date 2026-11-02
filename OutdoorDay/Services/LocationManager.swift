//
//  LocationManager.swift
//  Outdoor Day
//

import CoreLocation
import Foundation

@MainActor
final class LocationManager: NSObject, ObservableObject {
    @Published var coordinate: CLLocationCoordinate2D?
    @Published var placeName: String?
    @Published var authorizationDenied = false
    @Published var statusMessage: String?

    private let manager = CLLocationManager()
    private let geocoder = CLGeocoder()

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    func request() {
        statusMessage = nil
        // Screenshot tooling: skip the system location dialog and seed NYC.
        if Self.shouldSkipLocationPrompt {
            applyScreenshotLocation()
            return
        }
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse:
            manager.requestLocation()
        case .denied, .restricted:
            authorizationDenied = true
            statusMessage = "Location is off — enable it in Settings to get a local verdict."
        @unknown default:
            statusMessage = "Unable to read location permission."
        }
    }

    private static var shouldSkipLocationPrompt: Bool {
        UserDefaults.standard.bool(forKey: "skipATT")
            || ProcessInfo.processInfo.arguments.contains("-skipATT")
            || ProcessInfo.processInfo.environment["SKIP_ATT"] == "1"
    }

    private func applyScreenshotLocation() {
        authorizationDenied = false
        let nyc = CLLocationCoordinate2D(latitude: 40.7128, longitude: -74.0060)
        coordinate = nyc
        placeName = "New York, NY"
        statusMessage = nil
    }
}

extension LocationManager: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            switch manager.authorizationStatus {
            case .authorizedAlways, .authorizedWhenInUse:
                authorizationDenied = false
                manager.requestLocation()
            case .denied, .restricted:
                authorizationDenied = true
                statusMessage = "Location is off — enable it in Settings to get a local verdict."
            default:
                break
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        Task { @MainActor in
            coordinate = location.coordinate
            reverseGeocode(location)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            statusMessage = "Couldn’t get location: \(error.localizedDescription)"
        }
    }

    private func reverseGeocode(_ location: CLLocation) {
        geocoder.reverseGeocodeLocation(location) { [weak self] marks, _ in
            Task { @MainActor in
                guard let self else { return }
                if let mark = marks?.first {
                    let city = mark.locality ?? mark.subAdministrativeArea
                    let region = mark.administrativeArea
                    self.placeName = [city, region].compactMap { $0 }.joined(separator: ", ")
                }
            }
        }
    }
}
