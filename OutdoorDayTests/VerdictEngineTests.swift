import XCTest
@testable import OutdoorDay

final class VerdictEngineTests: XCTestCase {
    func testLowConditionsSayGo() {
        XCTAssertEqual(VerdictEngine.verdict(uv: 1.5, aqi: 20, pollen: 2), .go)
    }

    func testVeryHighUVSaysStay() {
        XCTAssertEqual(VerdictEngine.verdict(uv: 10, aqi: 20, pollen: 2), .stay)
    }

    func testHighPollenSaysCaution() {
        XCTAssertEqual(VerdictEngine.verdict(uv: 2, aqi: 30, pollen: 75), .caution)
    }

    func testTwoModeratesSayCaution() {
        XCTAssertEqual(VerdictEngine.verdict(uv: 4, aqi: 70, pollen: 5), .caution)
    }
}
