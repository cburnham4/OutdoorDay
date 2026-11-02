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

    /// Next three local calendar days: UV max + AQI max (+ pollen when Open-Meteo/social provide it).
    func fetchOutlook(latitude: Double, longitude: Double, todayPollen: (label: String, value: Double?)?) async throws -> [OutlookDay] {
        async let uvTask = fetchDailyUVMax(latitude: latitude, longitude: longitude, days: 3)
        async let aqiTask = fetchDailyAQIMax(latitude: latitude, longitude: longitude, days: 3)
        async let pollenTask = fetchDailyPollenMax(latitude: latitude, longitude: longitude, days: 3)
        async let socialTask = fetchSocialPollenForecast(latitude: latitude, longitude: longitude)
        let uvByDay = try await uvTask
        let aqiByDay = try await aqiTask
        let pollenByDay = (try? await pollenTask) ?? [:]
        let socialByDay = await socialTask

        let dayKeys = uvByDay.keys.sorted()
        let keys = dayKeys.isEmpty ? aqiByDay.keys.sorted() : dayKeys
        return keys.prefix(3).compactMap { key in
            guard let date = Self.dayFormatter.date(from: key) else { return nil }
            let pollen = pollenByDay[key] ?? socialByDay[key] ?? (Calendar.current.isDateInToday(date) ? todayPollen : nil)
            return OutlookDay(
                dateKey: key,
                date: date,
                uvIndexMax: uvByDay[key],
                usAqiMax: aqiByDay[key],
                pollenGrains: pollen?.value,
                pollenLabel: pollen?.label ?? "Pollen"
            )
        }
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
        let map = try await fetchDailyUVMax(latitude: latitude, longitude: longitude, days: 1)
        let today = Self.dayFormatter.string(from: Date())
        if let value = map[today] {
            return value
        }
        return map.values.first
    }

    private func fetchDailyUVMax(latitude: Double, longitude: Double, days: Int) async throws -> [String: Double] {
        var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
        components.queryItems = [
            URLQueryItem(name: "latitude", value: String(latitude)),
            URLQueryItem(name: "longitude", value: String(longitude)),
            URLQueryItem(name: "daily", value: "uv_index_max"),
            URLQueryItem(name: "forecast_days", value: String(days)),
            URLQueryItem(name: "timezone", value: "auto")
        ]
        let (data, response) = try await session.data(from: components.url!)
        try Self.validate(response)
        let decoded = try JSONDecoder().decode(DailyUVPayload.self, from: data)
        var map: [String: Double] = [:]
        let times = decoded.daily.time ?? []
        let values = decoded.daily.uv_index_max ?? []
        for (index, key) in times.enumerated() where index < values.count {
            map[key] = values[index]
        }
        return map
    }

    private func fetchDailyAQIMax(latitude: Double, longitude: Double, days: Int) async throws -> [String: Int] {
        var components = URLComponents(string: "https://air-quality-api.open-meteo.com/v1/air-quality")!
        components.queryItems = [
            URLQueryItem(name: "latitude", value: String(latitude)),
            URLQueryItem(name: "longitude", value: String(longitude)),
            URLQueryItem(name: "hourly", value: "us_aqi"),
            URLQueryItem(name: "forecast_days", value: String(days)),
            URLQueryItem(name: "timezone", value: "auto")
        ]
        let (data, response) = try await session.data(from: components.url!)
        try Self.validate(response)
        let decoded = try JSONDecoder().decode(HourlyAQIPayload.self, from: data)
        var map: [String: Int] = [:]
        let times = decoded.hourly.time ?? []
        let values = decoded.hourly.us_aqi ?? []
        for (index, stamp) in times.enumerated() where index < values.count {
            let key = String(stamp.prefix(10))
            guard let value = values[index] else { continue }
            map[key] = max(map[key] ?? value, value)
        }
        return map
    }

    private func fetchDailyPollenMax(latitude: Double, longitude: Double, days: Int) async throws -> [String: (label: String, value: Double?)] {
        var components = URLComponents(string: "https://air-quality-api.open-meteo.com/v1/air-quality")!
        components.queryItems = [
            URLQueryItem(name: "latitude", value: String(latitude)),
            URLQueryItem(name: "longitude", value: String(longitude)),
            URLQueryItem(
                name: "hourly",
                value: "alder_pollen,birch_pollen,grass_pollen,mugwort_pollen,olive_pollen,ragweed_pollen"
            ),
            URLQueryItem(name: "forecast_days", value: String(days)),
            URLQueryItem(name: "timezone", value: "auto")
        ]
        let (data, response) = try await session.data(from: components.url!)
        try Self.validate(response)
        let decoded = try JSONDecoder().decode(HourlyPollenPayload.self, from: data)
        let times = decoded.hourly.time ?? []
        var map: [String: (label: String, value: Double)] = [:]
        for (index, stamp) in times.enumerated() {
            let key = String(stamp.prefix(10))
            let pairs: [(String, Double)] = [
                ("Ragweed", Self.pollenAt(decoded.hourly.ragweed_pollen, index: index)),
                ("Grass", Self.pollenAt(decoded.hourly.grass_pollen, index: index)),
                ("Birch", Self.pollenAt(decoded.hourly.birch_pollen, index: index)),
                ("Alder", Self.pollenAt(decoded.hourly.alder_pollen, index: index)),
                ("Mugwort", Self.pollenAt(decoded.hourly.mugwort_pollen, index: index)),
                ("Olive", Self.pollenAt(decoded.hourly.olive_pollen, index: index))
            ].compactMap { label, value in
                guard let value else { return nil }
                return (label, value)
            }
            guard let top = pairs.max(by: { $0.1 < $1.1 }) else { continue }
            if let existing = map[key] {
                if top.1 > existing.value { map[key] = top }
            } else {
                map[key] = top
            }
        }
        return map.mapValues { (label: $0.label, value: Optional($0.value)) }
    }

    private static func pollenAt(_ values: [Double?]?, index: Int) -> Double? {
        guard let values, values.indices.contains(index) else { return nil }
        return values[index]
    }

    /// Soft-fail pollen fallback (same host pattern as Pollen Air Quality / PollenLevels).
    /// Maps categorical levels onto approximate grains/m³ for VerdictEngine.
    private func fetchSocialPollen(latitude: Double, longitude: Double) async -> (label: String, value: Double?)? {
        let map = await fetchSocialPollenForecast(latitude: latitude, longitude: longitude)
        let today = Self.dayFormatter.string(from: Date())
        return map[today] ?? map.values.first
    }

    private func fetchSocialPollenForecast(latitude: Double, longitude: Double) async -> [String: (label: String, value: Double?)] {
        let latLong = String(format: "[%f,%f]", latitude, longitude)
        guard let encoded = latLong.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://socialpollencount.co.uk/api/forecast?location=\(encoded)")
        else { return [:] }

        var request = URLRequest(url: url)
        request.timeoutInterval = 8
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                return [:]
            }
            let decoded = try JSONDecoder().decode(SocialPollenResponse.self, from: data)
            return decoded.mappedByDay
        } catch {
            return [:]
        }
    }

    private static func validate(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
    }

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
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

private struct DailyUVPayload: Decodable {
    let daily: DailyUV
}

private struct DailyUV: Decodable {
    let time: [String]?
    let uv_index_max: [Double]?
}

private struct HourlyAQIPayload: Decodable {
    let hourly: HourlyAQI
}

private struct HourlyAQI: Decodable {
    let time: [String]?
    let us_aqi: [Int?]?
}

private struct HourlyPollenPayload: Decodable {
    let hourly: HourlyPollen
}

private struct HourlyPollen: Decodable {
    let time: [String]?
    let alder_pollen: [Double?]?
    let birch_pollen: [Double?]?
    let grass_pollen: [Double?]?
    let mugwort_pollen: [Double?]?
    let olive_pollen: [Double?]?
    let ragweed_pollen: [Double?]?
}

private struct SocialPollenResponse: Decodable {
    let forecast: [SocialPollenDay]

    var mappedByDay: [String: (label: String, value: Double?)] {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        var map: [String: (label: String, value: Double?)] = [:]
        for entry in forecast {
            guard let date = formatter.date(from: entry.date) else { continue }
            let key = OpenMeteoClientDayKey.string(from: date)
            map[key] = entry.mapped
        }
        return map
    }
}

private enum OpenMeteoClientDayKey {
    static func string(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
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
