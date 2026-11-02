//
//  DayConditions.swift
//  Outdoor Day
//

import Foundation
import SwiftUI

enum OutdoorVerdict: String {
    case go = "Go outside"
    case caution = "Go with care"
    case stay = "Better stay in"

    var detail: String {
        switch self {
        case .go:
            return "UV, pollen, and air look friendly enough for outdoor time."
        case .caution:
            return "One or more factors are elevated — limit time, cover up, or pick a milder window."
        case .stay:
            return "Conditions look rough for allergies or sun/air exposure today."
        }
    }

    var symbolName: String {
        switch self {
        case .go: return "sun.max.fill"
        case .caution: return "exclamationmark.triangle.fill"
        case .stay: return "house.fill"
        }
    }
}

struct DayConditions: Equatable {
    var uvIndex: Double?
    var usAqi: Int?
    var pollenGrains: Double?
    var pollenLabel: String
    var fetchedAt: Date
    var latitude: Double
    var longitude: Double

    var verdict: OutdoorVerdict {
        VerdictEngine.verdict(uv: uvIndex, aqi: usAqi, pollen: pollenGrains)
    }
}

/// One calendar day in the Outdoor Day Plus outlook.
struct OutlookDay: Equatable, Identifiable {
    var id: String { dateKey }
    var dateKey: String
    var date: Date
    var uvIndexMax: Double?
    var usAqiMax: Int?
    var pollenGrains: Double?
    var pollenLabel: String

    var verdict: OutdoorVerdict {
        VerdictEngine.verdict(uv: uvIndexMax, aqi: usAqiMax, pollen: pollenGrains)
    }

    var weekdayLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: date)
    }
}

enum RiskBand: String {
    case low = "Low"
    case moderate = "Moderate"
    case high = "High"
    case veryHigh = "Very high"
    case unknown = "—"
}

enum VerdictEngine {
    static func uvBand(_ uv: Double?) -> RiskBand {
        guard let uv else { return .unknown }
        switch uv {
        case ..<3: return .low
        case ..<6: return .moderate
        case ..<8: return .high
        default: return .veryHigh
        }
    }

    static func aqiBand(_ aqi: Int?) -> RiskBand {
        guard let aqi else { return .unknown }
        switch aqi {
        case ..<51: return .low
        case ..<101: return .moderate
        case ..<151: return .high
        default: return .veryHigh
        }
    }

    /// Open-Meteo pollen is grains/m³; thresholds approximate common allergy guidance.
    static func pollenBand(_ grains: Double?) -> RiskBand {
        guard let grains else { return .unknown }
        switch grains {
        case ..<10: return .low
        case ..<50: return .moderate
        case ..<100: return .high
        default: return .veryHigh
        }
    }

    static func verdict(uv: Double?, aqi: Int?, pollen: Double?) -> OutdoorVerdict {
        let bands = [uvBand(uv), aqiBand(aqi), pollenBand(pollen)]
        if bands.contains(.veryHigh) { return .stay }
        if bands.contains(.high) { return .caution }
        if bands.filter({ $0 == .moderate }).count >= 2 { return .caution }
        if bands.contains(.unknown) && bands.contains(where: { $0 == .moderate || $0 == .high }) {
            return .caution
        }
        return .go
    }
}

extension RiskBand {
    var tint: Color {
        switch self {
        case .low: return Color(red: 0.20, green: 0.62, blue: 0.38)
        case .moderate: return Color(red: 0.90, green: 0.62, blue: 0.12)
        case .high: return Color(red: 0.90, green: 0.40, blue: 0.12)
        case .veryHigh: return Color(red: 0.78, green: 0.18, blue: 0.22)
        case .unknown: return .secondary
        }
    }
}

extension OutdoorVerdict {
    var tint: Color {
        switch self {
        case .go: return Color(red: 0.20, green: 0.62, blue: 0.38)
        case .caution: return Color(red: 0.90, green: 0.55, blue: 0.10)
        case .stay: return Color(red: 0.78, green: 0.18, blue: 0.22)
        }
    }
}
