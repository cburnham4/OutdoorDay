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
        async let aqTask = fetchAirQuality(latitude: latitude, longitude: longitude)
        async let uvTask = fetchDayUV(latitude: latitude, longitude: longitude)
        async let socialTask = fetchSocialPollen(latitude: latitude, longitude: longitude)
        let aq = try await aqTask
        let dayUV = try? await uvTask
        let social = await socialTask

        // Prefer today's max UV so nighttime launches still reflect the day.
        let uv = dayUV ?? aq.current.uv_index
        var pollen = aq.bestPollen
        // Open-Meteo species pollen is mostly Europe/CAMS; fall back for US/elsewhere.
        if pollen.value == nil, let social {
            pollen = social
        }
        return DayConditions(
            uvIndex: uv,
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

    private func fetchDayUV(latitude: Double, longitude: Double) async throws -> Double? {
        var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
        components.queryItems = [
            URLQueryItem(name: "latitude", value: String(latitude)),
            URLQueryItem(name: "longitude", value: String(longitude)),
            URLQueryItem(name: "current", value: "uv_index"),
            URLQueryItem(name: "daily", value: "uv_index_max"),
            URLQueryItem(name: "forecast_days", value: "1"),
            URLQueryItem(name: "timezone", value: "auto")
        ]
        let (data, response) = try await session.data(from: components.url!)
        try Self.validate(response)
        let decoded = try JSONDecoder().decode(ForecastPayload.self, from: data)
        if let max = decoded.daily.uv_index_max?.first {
            return max
        }
        return decoded.current.uv_index
    }

    /// Soft-fail pollen fallback (same host pattern as Pollen Air Quality / PollenLevels).
    /// Maps categorical levels onto approximate grains/m³ for VerdictEngine.
    private func fetchSocialPollen(latitude: Double, longitude: Double) async -> (label: String, value: Double?)? {
        let latLong = String(format: "[%f,%f]", latitude, longitude)
        guard let encoded = latLong.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://socialpollencount.co.uk/api/forecast?location=\(encoded)")
        else { return nil }

        var request = URLRequest(url: url)
        request.timeoutInterval = 8
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                return nil
            }
            let decoded = try JSONDecoder().decode(SocialPollenResponse.self, from: data)
            return decoded.todaysMapped
        } catch {
            return nil
        }
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
    let daily: DailyForecast
}

private struct CurrentForecast: Decodable {
    let uv_index: Double?
}

private struct DailyForecast: Decodable {
    let uv_index_max: [Double]?
}

private struct SocialPollenResponse: Decodable {
    let forecast: [SocialPollenDay]

    var todaysMapped: (label: String, value: Double?)? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        let day = forecast.first { entry in
            guard let date = formatter.date(from: entry.date) else { return false }
            return Calendar.current.isDateInToday(date)
        } ?? forecast.first
        guard let day else { return nil }
        return day.mapped
    }
}

private struct SocialPollenDay: Decodable {
    let pollen_count: String
    let date: String

    /// Approximate grains/m³ so existing VerdictEngine thresholds still apply.
    var mapped: (label: String, value: Double?) {
        switch pollen_count.lowercased() {
        case "low":
            return ("Pollen", 5)
        case "moderate":
            return ("Pollen", 30)
        case "high":
            return ("Pollen", 75)
        case "very high", "veryhigh":
            return ("Pollen", 150)
        default:
            return ("Pollen", nil)
        }
    }
}
