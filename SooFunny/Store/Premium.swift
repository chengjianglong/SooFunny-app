import Observation
import StoreKit
import SwiftUI

// The developer unlock exists only in Debug builds (DEV_UNLOCK is set for the Debug
// configuration in project.yml). App Store and TestFlight builds are always Release.
#if DEV_UNLOCK && !DEBUG
#error("DEV_UNLOCK must never be enabled outside Debug builds")
#endif

/// SooFunny Premium: a yearly auto-renewing subscription ($19.99/year, 7-day free trial),
/// sold through the App Store. StoreKit keeps the purchase on the device, so the app keeps
/// working offline after subscribing.
@MainActor
@Observable
final class Premium {
    static let shared = Premium()

    static let yearlyID = "com.chengjianglong.soofunny.premium.yearly"
    static let privacyPolicyURL = URL(string: "https://github.com/chengjianglong/SooFunny-app/blob/main/PRIVACY.md")!
    /// Apple's standard license agreement (EULA) for App Store apps.
    static let termsURL = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!

    /// True while the subscription (or its free trial) is active.
    private(set) var isActive = false
    private(set) var expirationDate: Date?
    private(set) var willRenew = true

    /// Debug builds installed from Xcode unlock everything, so the developer can try Premium
    /// features on their own devices. Always false in Release (App Store) builds.
    nonisolated static var isDeveloperUnlockBuild: Bool {
        #if DEV_UNLOCK
        return true
        #else
        return false
        #endif
    }

    /// True when this build unlocks Premium without a purchase.
    let developerUnlock: Bool

    @ObservationIgnored private var updates: Task<Void, Never>?

    init(developerUnlock: Bool = Premium.isDeveloperUnlockBuild) {
        self.developerUnlock = developerUnlock
        // Purchases made elsewhere (Family Sharing, another device, renewals) arrive here.
        updates = Task { [weak self] in
            for await result in Transaction.updates {
                if case .verified(let transaction) = result { await transaction.finish() }
                await self?.refresh()
            }
        }
        Task { await refresh() }
    }

    /// Re-reads the current subscription state from StoreKit's on-device cache.
    func refresh() async {
        var active = false
        var expiration: Date?
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result,
                  transaction.productID == Self.yearlyID,
                  transaction.revocationDate == nil else { continue }
            if let date = transaction.expirationDate, date < Date() { continue }
            active = true
            expiration = transaction.expirationDate
        }
        isActive = active || developerUnlock
        expirationDate = expiration
        if active, let status = try? await Product.products(for: [Self.yearlyID]).first?.subscription?.status.first,
           case .verified(let info) = status.renewalInfo {
            willRenew = info.willAutoRenew
        }
    }

    /// Asks the App Store for this Apple ID's purchases (for "Restore Purchases").
    func restore() async throws {
        try await AppStore.sync()
        await refresh()
    }
}

/// What the free version includes. Everything else needs Premium.
enum FreeTier {
    /// Word groups anyone can open.
    static let wordCategories: Set<String> = ["Animals", "Colors", "Numbers"]
    /// Math operations anyone can practice.
    static let mathOperations: Set<MathOperation> = [.add, .subtract]

    static func allows(_ picture: ShowcasePicture) -> Bool { picture.kind == .drawings }
    static func allows(_ category: WordCategory) -> Bool { wordCategories.contains(category.name) }
}

// MARK: - Paywall

/// A grown-up check, then the subscription offer. Children can't subscribe on their own.
struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var gatePassed = false
    private let premium = Premium.shared

    var body: some View {
        NavigationStack {
            Group {
                if gatePassed {
                    store
                } else {
                    ParentalGate(reason: "Subscriptions are for grown-ups.") { gatePassed = true }
                }
            }
            .toolbar {
                // The subscription screen has its own close button.
                if !gatePassed {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close") { dismiss() }
                    }
                }
            }
        }
        .onChange(of: premium.isActive) { _, active in if active { dismiss() } }
    }

    private var store: some View {
        SubscriptionStoreView(productIDs: [Premium.yearlyID]) {
            VStack(spacing: 14) {
                Text("SooFunny Premium")
                    .font(.system(size: 36, weight: .black, design: .rounded))
                    .foregroundStyle(LinearGradient(colors: [.pink, .orange, .purple], startPoint: .leading, endPoint: .trailing))
                VStack(alignment: .leading, spacing: 10) {
                    perk("🖼️", "Color every photo, plus your own photos and camera")
                    perk("📚", "All 32 word groups, 754 words")
                    perk("✨", "The talking buddy, running on your device")
                    perk("✖️", "Times and sharing (× ÷) in Math")
                    perk("📴", "Works offline, no ads, nothing leaves your device")
                }
                .font(.headline)
                Text("Free for 7 days, then $19.99 a year. Cancel anytime in Settings.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding()
        }
        .subscriptionStoreControlStyle(.prominentPicker)
        .storeButton(.visible, for: .restorePurchases, .policies)
        .subscriptionStorePolicyDestination(url: Premium.privacyPolicyURL, for: .privacyPolicy)
        .subscriptionStorePolicyDestination(url: Premium.termsURL, for: .termsOfService)
        .onInAppPurchaseCompletion { _, _ in await premium.refresh() }
    }

    private func perk(_ emoji: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(emoji)
            Text(text)
        }
    }
}

/// "Ask a grown-up": a multiplication question young children can't answer, shown before
/// purchases and links that leave the app.
struct ParentalGate: View {
    let reason: String
    let onPass: () -> Void

    @State private var question = ParentalGate.makeQuestion()
    @State private var answer = ""
    @State private var wrong = false
    @FocusState private var focused: Bool

    static func makeQuestion() -> (Int, Int) { (Int.random(in: 12...19), Int.random(in: 6...9)) }

    var body: some View {
        VStack(spacing: 18) {
            Text("👨‍👩‍👧").font(.system(size: 64))
            Text("Ask a grown-up").font(.largeTitle.weight(.heavy))
            Text(reason).foregroundStyle(.secondary)
            Text("What is \(question.0) × \(question.1)?")
                .font(.title.weight(.bold).monospacedDigit())
            TextField("Answer", text: $answer)
                .keyboardType(.numberPad)
                .font(.title2.monospacedDigit())
                .multilineTextAlignment(.center)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 200)
                .focused($focused)
                .onSubmit(check)
            if wrong {
                Text("That's not right. Try this one.").foregroundStyle(.red)
            }
            Button("Continue", action: check)
                .buttonStyle(.borderedProminent)
                .font(.headline)
                .disabled(answer.isEmpty)
        }
        .padding(32)
        .frame(maxWidth: 520)
        .onAppear { focused = true }
    }

    private func check() {
        if Int(answer.trimmingCharacters(in: .whitespaces)) == question.0 * question.1 {
            onPass()
        } else {
            wrong = true
            answer = ""
            question = Self.makeQuestion()
        }
    }
}

/// A small lock badge for premium items.
struct PremiumBadge: View {
    var body: some View {
        Image(systemName: "lock.fill")
            .font(.system(size: 14, weight: .bold))
            .foregroundStyle(.white)
            .padding(7)
            .background(Color.black.opacity(0.55), in: Circle())
            .accessibilityLabel("Premium")
    }
}
