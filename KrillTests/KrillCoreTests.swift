import XCTest
@testable import Krill

final class KrillCoreTests: XCTestCase {
    func testFilterTimestampUsesShanghaiRegardlessOfDeviceTimeZone() throws {
        let date = try XCTUnwrap(KrillDate.parse("2026-10-26T16:00:00Z"))
        XCTAssertEqual(KrillDate.filterString(date), "2026-10-27T00:00:00")
    }

    func testUnzonedServerDateIsInterpretedAsShanghai() throws {
        let local = try XCTUnwrap(KrillDate.parse("2026-10-27T00:00:00"))
        let utc = try XCTUnwrap(KrillDate.parse("2026-10-26T16:00:00Z"))
        XCTAssertEqual(local, utc)
    }

    func testFractionalTimestampAndInvalidInput() throws {
        let date = try XCTUnwrap(KrillDate.parse("2026-10-26T16:00:00.125Z"))
        let whole = try XCTUnwrap(KrillDate.parse("2026-10-26T16:00:00Z"))
        XCTAssertEqual(date.timeIntervalSince(whole), 0.125, accuracy: 0.001)
        XCTAssertNil(KrillDate.parse("invalid timestamp"))
    }

    func testSevenDayRangeIncludesTodayAndSixPreviousCalendarDays() throws {
        let now = try XCTUnwrap(KrillDate.parse("2026-10-27T17:30:00"))
        let range = KrillDate.range(for: .week, now: now)
        XCTAssertEqual(KrillDate.filterString(range.start), "2026-10-21T00:00:00")
        XCTAssertEqual(range.end, now)
    }

    func testThirtyDayRangeCrossesMonthBoundary() throws {
        let now = try XCTUnwrap(KrillDate.parse("2026-10-27T17:30:00"))
        let range = KrillDate.range(for: .month, now: now)
        XCTAssertEqual(KrillDate.filterString(range.start), "2026-09-28T00:00:00")
    }

    func testRequestHTTPStatusClassification() {
        func row(_ status: String) -> RequestLog {
            RequestLog(id: "test", model: "test-model", date: .distantPast, cost: 0,
                       inputTokens: 0, outputTokens: 0, cacheReadTokens: 0,
                       cacheWriteTokens: 0, reasoningTokens: 0, durationMS: 0,
                       status: status, method: "3", tokenName: "")
        }
        XCTAssertTrue(row("200").isSuccess)
        XCTAssertTrue(row("201").isSuccess)
        XCTAssertFalse(row("429").isSuccess)
        XCTAssertFalse(row("500").isSuccess)
        XCTAssertFalse(row("unknown").isSuccess)
    }
}
