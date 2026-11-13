import StoreKit
import StoreKitTest
import XCTest
@testable import SooFunny

/// The tip products in SooFunny.storekit match what the app offers.
final class TipJarConfigTests: XCTestCase {
    func testStoreKitConfigOffersThreeTips() throws {
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "SooFunny", withExtension: "storekit"))
        let config = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        let products = try XCTUnwrap(config["products"] as? [[String: Any]])
        let tips = Dictionary(uniqueKeysWithValues: products.map { ($0["productID"] as? String ?? "", $0) })
        XCTAssertEqual(Set(tips.keys), Set(TipJar.tipIDs))
        XCTAssertEqual(TipJar.tipIDs.map { tips[$0]?["displayPrice"] as? String }, ["1.99", "4.99", "9.99"])
        XCTAssertTrue(tips.values.allSatisfy { $0["type"] as? String == "Consumable" }, "tips unlock nothing")
    }
}

/// Runs real StoreKit flows against SooFunny.storekit (no App Store needed).
@MainActor
final class TipJarTests: XCTestCase {
    private var session: SKTestSession!

    override func setUp() async throws {
        session = try SKTestSession(configurationFileNamed: "SooFunny")
        session.resetToDefaultState()
        session.clearTransactions()
        session.disableDialogs = true
    }

    /// Skips (rather than fails) when the Simulator's StoreKit test service can't be reached,
    /// which happens in some command-line runs; run these from Xcode (Product → Test).
    private func products(_ ids: [String]) async throws -> [Product] {
        let products = try await Product.products(for: ids)
        guard products.count == ids.count else {
            throw XCTSkip("StoreKit test session unavailable here; run TipJarTests from Xcode.")
        }
        return products
    }

    func testTipsHavePrices() async throws {
        let prices = try await products(TipJar.tipIDs).sorted { $0.price < $1.price }.map(\.price)
        XCTAssertEqual(prices, [Decimal(string: "1.99"), Decimal(string: "4.99"), Decimal(string: "9.99")])
    }

    func testATipFinishesAndUnlocksNothing() async throws {
        let tip = try await products([TipJar.tipIDs[0]])[0]
        XCTAssertEqual(tip.type, .consumable)
        guard case .success(.verified(let transaction)) = try await tip.purchase() else {
            return XCTFail("the tip should go through")
        }
        await transaction.finish()
        var entitlements = 0
        for await _ in Transaction.currentEntitlements { entitlements += 1 }
        XCTAssertEqual(entitlements, 0, "a tip leaves nothing to restore")
    }

    func testOldSubscribersAreShownHowToCancel() async throws {
        let jar = TipJar()
        await jar.refresh()
        XCTAssertFalse(jar.hasLegacySubscription)

        let yearly = try await products([TipJar.legacySubscriptionID])[0]
        _ = try await yearly.purchase()
        await jar.refresh()
        XCTAssertTrue(jar.hasLegacySubscription)

        try session.expireSubscription(productIdentifier: TipJar.legacySubscriptionID)
        for _ in 0..<50 where jar.hasLegacySubscription {
            await jar.refresh()
            try? await Task.sleep(for: .milliseconds(100))
        }
        XCTAssertFalse(jar.hasLegacySubscription, "an ended subscription needs no reminder")
    }
}
