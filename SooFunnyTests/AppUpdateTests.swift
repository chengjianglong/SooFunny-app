import XCTest
@testable import SooFunny

@MainActor
final class AppUpdateTests: XCTestCase {
    private var defaults: UserDefaults!

    override func setUp() {
        defaults = UserDefaults(suiteName: "AppUpdateTests")!
        defaults.removePersistentDomain(forName: "AppUpdateTests")
    }

    func testVersionComparison() {
        XCTAssertTrue(AppUpdateChecker.isNewer("0.5", than: "0.4"))
        XCTAssertTrue(AppUpdateChecker.isNewer("0.10", than: "0.9"))
        XCTAssertTrue(AppUpdateChecker.isNewer("1.0.1", than: "1.0"))
        XCTAssertFalse(AppUpdateChecker.isNewer("1.0", than: "1"))
        XCTAssertFalse(AppUpdateChecker.isNewer("0.4", than: "0.4"))
        XCTAssertFalse(AppUpdateChecker.isNewer("0.3", than: "0.4"))
    }

    func testParsesLookup() {
        let json = #"{"resultCount":1,"results":[{"trackId":6827777441,"version":"0.5"}]}"#
        XCTAssertEqual(AppUpdateChecker.version(fromLookup: Data(json.utf8)), "0.5")
        XCTAssertNil(AppUpdateChecker.version(fromLookup: Data(#"{"resultCount":0,"results":[]}"#.utf8)))
        XCTAssertNil(AppUpdateChecker.version(fromLookup: Data("oops".utf8)))
    }

    private final class Counter: @unchecked Sendable { var calls = 0 }

    private func checker(latest: String?, counter: Counter = Counter()) -> AppUpdateChecker {
        AppUpdateChecker(defaults: defaults) { _ in
            counter.calls += 1
            guard let latest else { throw URLError(.notConnectedToInternet) }
            return Data(#"{"results":[{"version":"\#(latest)"}]}"#.utf8)
        }
    }

    func testOffersNewerVersion() async {
        let c = checker(latest: "0.5")
        await c.checkIfDue(installed: "0.4")
        XCTAssertEqual(c.available, "0.5")
    }

    func testNothingWhenUpToDateOrOffline() async {
        let same = checker(latest: "0.4")
        await same.checkIfDue(installed: "0.4")
        XCTAssertNil(same.available)

        let offline = checker(latest: nil)
        await offline.checkIfDue(installed: "0.4")
        XCTAssertNil(offline.available)
    }

    func testNotNowHidesForThreeDays() async {
        let c = checker(latest: "0.5")
        let now = Date()
        await c.checkIfDue(installed: "0.4", now: now)
        c.snooze(now: now)
        XCTAssertNil(c.available)

        await c.checkIfDue(installed: "0.4", now: now.addingTimeInterval(24 * 3600), force: true)
        XCTAssertNil(c.available, "still snoozed after one day")

        await c.checkIfDue(installed: "0.4", now: now.addingTimeInterval(4 * 24 * 3600), force: true)
        XCTAssertEqual(c.available, "0.5", "back after three days")
    }

    func testSnoozeDoesNotHideALaterVersion() {
        let now = Date()
        XCTAssertTrue(AppUpdateChecker.shouldOffer(latest: "0.6", installed: "0.4", snoozedVersion: "0.5",
                                                   snoozedUntil: now.addingTimeInterval(3600), now: now))
    }

    func testChecksAtMostEverySixHours() async {
        let counter = Counter()
        let c = checker(latest: "0.4", counter: counter)
        let now = Date()
        await c.checkIfDue(installed: "0.4", now: now)
        XCTAssertEqual(counter.calls, 1)
        await c.checkIfDue(installed: "0.4", now: now.addingTimeInterval(3600))
        XCTAssertEqual(counter.calls, 1, "skipped within six hours")
        await c.checkIfDue(installed: "0.4", now: now.addingTimeInterval(7 * 3600))
        XCTAssertEqual(counter.calls, 2)
    }
}
