import StoreKit
import StoreKitTest
import XCTest
@testable import SooFunny

/// Runs real StoreKit purchase flows against SooFunny.storekit (no App Store needed).
@MainActor
final class PremiumTests: XCTestCase {
    private var session: SKTestSession!

    override func setUp() async throws {
        session = try SKTestSession(configurationFileNamed: "SooFunny")
        session.resetToDefaultState()
        session.clearTransactions()
        session.disableDialogs = true
    }

    /// The test product. Skips (rather than fails) when the Simulator's StoreKit test service
    /// can't be reached, which happens in some sandboxed command-line runs; run these from
    /// Xcode (Product → Test) to exercise real purchases.
    private func product() async throws -> Product {
        let products = try await Product.products(for: [Premium.yearlyID])
        guard let product = products.first else {
            throw XCTSkip("StoreKit test session unavailable here; run PremiumTests from Xcode.")
        }
        return product
    }

    /// StoreKit applies expiries and refunds asynchronously; re-check for up to five seconds.
    private func waitUntilLocked(_ premium: Premium) async -> Bool {
        for _ in 0..<50 {
            await premium.refresh()
            if !premium.isActive { return true }
            try? await Task.sleep(for: .milliseconds(100))
        }
        return false
    }

    func testYearlyProductHasPriceAndFreeTrial() async throws {
        let product = try await product()
        XCTAssertEqual(product.price, Decimal(string: "19.99"))
        XCTAssertEqual(product.subscription?.subscriptionPeriod.unit, .year)
        XCTAssertEqual(product.subscription?.subscriptionPeriod.value, 1)
        let trial = try XCTUnwrap(product.subscription?.introductoryOffer)
        XCTAssertEqual(trial.paymentMode, .freeTrial)
        XCTAssertEqual(trial.period.unit, .week)
        XCTAssertEqual(trial.period.value, 1)
    }

    func testPurchaseUnlocksAndCancelledSubscriptionLocksWhenItEnds() async throws {
        let premium = Premium(developerUnlock: false)
        await premium.refresh()
        XCTAssertFalse(premium.isActive)

        let result = try await product().purchase()
        guard case .success(.verified(let transaction)) = result else { return XCTFail("purchase failed: \(result)") }
        await transaction.finish()
        await premium.refresh()
        XCTAssertTrue(premium.isActive)
        XCTAssertNotNil(premium.expirationDate)

        // With auto-renew on, ending a period just renews it; a family that cancels lapses.
        try session.disableAutoRenewForTransaction(identifier: UInt(transaction.id))
        try session.expireSubscription(productIdentifier: Premium.yearlyID)
        let locked = await waitUntilLocked(premium)
        XCTAssertTrue(locked, "a cancelled subscription should lock Premium when it ends")
    }

    func testRefundLocks() async throws {
        let premium = Premium(developerUnlock: false)
        let result = try await product().purchase()
        guard case .success(.verified(let transaction)) = result else { return XCTFail("purchase failed") }
        await transaction.finish()
        await premium.refresh()
        XCTAssertTrue(premium.isActive)

        try session.refundTransaction(identifier: UInt(transaction.id))
        let locked = await waitUntilLocked(premium)
        XCTAssertTrue(locked, "refunded subscription should lock Premium")
    }
}

final class DeveloperUnlockTests: XCTestCase {
    @MainActor
    func testUnlockOnlyInDebugBuilds() async {
        #if DEBUG
        XCTAssertTrue(Premium.isDeveloperUnlockBuild, "Debug builds unlock Premium for the developer")
        let premium = Premium()
        await premium.refresh()
        XCTAssertTrue(premium.isActive)
        #else
        XCTAssertFalse(Premium.isDeveloperUnlockBuild, "Release builds must never unlock Premium")
        #endif
    }
}

final class FreeTierTests: XCTestCase {
    func testFreeTierIsATaste() throws {
        let categories = try WordDictionary.loadBundled(Bundle(for: ColoringSession.self))
        let free = categories.filter(FreeTier.allows)
        XCTAssertEqual(Set(free.map(\.name)), FreeTier.wordCategories, "every free group exists")
        XCTAssertLessThan(free.count, categories.count)
        XCTAssertEqual(FreeTier.mathOperations, [.add, .subtract])
        XCTAssertTrue(Showcase.all.contains { FreeTier.allows($0) }, "some pictures are free")
        XCTAssertTrue(Showcase.all.contains { !FreeTier.allows($0) }, "some pictures need Premium")
    }
}
