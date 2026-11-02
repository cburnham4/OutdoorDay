//
//  OpenMeteoClient.swift
//  Outdoor Day
//
//  Free location weather/AQ APIs — no key required for basic current conditions.
//

import Foundation

struct OpenMeteoClient {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetchConditions(latitude: Double, longitude: Double) async throws -> DayConditions {
        let aq = try await fetchAirQuality(latitude: latitude, longitude: longitude)
        let uvFallback = try? await fetchForecastUV(latitude: latitude, longitude: longitude)

        let pollen = aq.bestPollen
        return DayConditions(
            uvIndex: aq.current.uv_index ?? uvFallback,
            usAqi: aq.current.us_aqi,
            pollenGrains: pollen.value,
            pollenLabel: pollen.label,
            fetchedAt: Date(),
            latitude: latitude,
            longitude: longitude
        )
    }

    private func fetchAirQuality(latitude: Double, longitude: Double) async throws -> AirQualityPayload {
        var components = URLComponents(string: "https://air-quality-api.open-meteo.com/v1/air-quality")!
        components.queryItems = [
            URLQueryItem(name: "latitude", value: String(latitude)),
            URLQueryItem(name: "longitude", value: String(longitude)),
            URLQueryItem(
                name: "current",
                value: "us_aqi,uv_index,alder_pollen,birch_pollen,grass_pollen,mugwort_pollen,olive_pollen,ragweed_pollen"
            ),
            URLQueryItem(name: "timezone", value: "auto")
        ]
        let (data, response) = try await session.data(from: components.url!)
        try Self.validate(response)
        return try JSONDecoder().decode(AirQualityPayload.self, from: data)
    }

    private func fetchForecastUV(latitude: Double, longitude: Double) async throws -> Double? {
        var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
        components.queryItems = [
            URLQueryItem(name: "latitude", value: String(latitude)),
            URLQueryItem(name: "longitude", value: String(longitude)),
            URLQueryItem(name: "current", value: "uv_index"),
            URLQueryItem(name: "timezone", value: "auto")
        ]
        let (data, response) = try await session.data(from: components.url!)
        try Self.validate(response)
        let decoded = try JSONDecoder().decode(ForecastPayload.self, from: data)
        return decoded.current.uv_index
    }

    private static func validate(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
    }
}

private struct AirQualityPayload: Decodable {
    let current: CurrentAQ

    var bestPollen: (label: String, value: Double?) {
        let pairs: [(String, Double?)] = [
            ("Ragweed", current.ragweed_pollen),
            ("Grass", current.grass_pollen),
            ("Birch", current.birch_pollen),
            ("Alder", current.alder_pollen),
            ("Mugwort", current.mugwort_pollen),
            ("Olive", current.olive_pollen)
        ]
        let available = pairs.compactMap { name, value -> (String, Double)? in
            guard let value else { return nil }
            return (name, value)
        }
        guard let top = available.max(by: { $0.1 < $1.1 }) else {
            return ("Pollen", nil)
        }
        return (top.0, top.1)
    }
}

private struct CurrentAQ: Decodable {
    let us_aqi: Int?
    let uv_index: Double?
    let alder_pollen: Double?
    let birch_pollen: Double?
    let grass_pollen: Double?
    let mugwort_pollen: Double?
    let olive_pollen: Double?
    let ragweed_pollen: Double?
}

private struct ForecastPayload: Decodable {
    let current: CurrentForecast
}

private struct CurrentForecast: Decodable {
    let uv_index: Double?
}
