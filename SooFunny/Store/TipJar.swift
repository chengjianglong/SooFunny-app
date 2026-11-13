import Observation
import StoreKit
import SwiftUI

/// SooFunny is free, with every feature for everyone. Grown-ups who'd like to help keep it
/// maintained and updated can leave a one-time tip: a consumable In-App Purchase that unlocks
/// nothing, sold through the App Store.
@MainActor
@Observable
final class TipJar {
    static let shared = TipJar()

    /// Small, medium and large tips ($1.99, $4.99 and $9.99 in the US).
    static let tipIDs = ["com.chengjianglong.soofunny.tip.small",
                         "com.chengjianglong.soofunny.tip.medium",
                         "com.chengjianglong.soofunny.tip.large"]
    /// The yearly subscription SooFunny sold before it became free. It's no longer offered;
    /// anyone still subscribed is shown how to cancel it.
    static let legacySubscriptionID = "com.chengjianglong.soofunny.premium.yearly"

    /// True while an old SooFunny Premium subscription is still set to renew.
    private(set) var hasLegacySubscription = false

    @ObservationIgnored private var updates: Task<Void, Never>?

    init() {
        // Purchases finished elsewhere (another device, Ask to Buy, renewals) arrive here.
        updates = Task { [weak self] in
            for await result in Transaction.updates {
                if case .verified(let transaction) = result { await transaction.finish() }
                await self?.refresh()
            }
        }
        Task { await refresh() }
    }

    /// Re-reads whether an old subscription is still renewing, from StoreKit's on-device cache.
    func refresh() async {
        var renewing = false
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result,
                  transaction.productID == Self.legacySubscriptionID,
                  transaction.revocationDate == nil else { continue }
            if let date = transaction.expirationDate, date < Date() { continue }
            renewing = true
            if let status = try? await Product.products(for: [Self.legacySubscriptionID]).first?.subscription?.status.first,
               case .verified(let info) = status.renewalInfo {
                renewing = info.willAutoRenew
            }
        }
        hasLegacySubscription = renewing
    }
}

// MARK: - Support screen

/// A grown-up check, then the tips. Children can't tip on their own.
struct SupportView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var gatePassed = false
    @State private var thanked = false
    /// True when the App Store couldn't be reached (SooFunny is often used offline).
    @State private var offline = false

    var body: some View {
        NavigationStack {
            Group {
                if gatePassed {
                    tips
                } else {
                    ParentalGate(reason: "Tips are for grown-ups.") { gatePassed = true }
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }

    private var tips: some View {
        ScrollView {
            VStack(spacing: 18) {
                Text(thanked ? "💛" : "💖").font(.system(size: 64))
                Text(thanked ? "Thank you!" : "Support SooFunny")
                    .font(.system(size: 34, weight: .black, design: .rounded))
                    .foregroundStyle(LinearGradient(colors: [.pink, .orange, .purple], startPoint: .leading, endPoint: .trailing))
                Text(thanked
                     ? "Your tip helps keep SooFunny maintained and growing, free for every family."
                     : "SooFunny is free for everyone, with no ads and no tracking. If your family enjoys it, a tip helps keep it maintained and add new things to learn.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                if offline {
                    Label("Tips need an internet connection. Please try again when you're online.", systemImage: "wifi.slash")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.orange)
                        .multilineTextAlignment(.center)
                }
                VStack(spacing: 12) {
                    ForEach(Array(zip(TipJar.tipIDs, ["☕️", "🍰", "🎁"])), id: \.0) { id, emoji in
                        ProductView(id: id) {
                            Text(emoji).font(.system(size: 36))
                        }
                        .productViewStyle(.compact)
                        .padding(14)
                        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18))
                    }
                }
                Text("Tips are optional, one-time payments. They don't unlock anything: every feature is already free.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(24)
            .frame(maxWidth: 520)
            .frame(maxWidth: .infinity)
        }
        .background(Color(.systemGroupedBackground))
        .task {
            let products = (try? await Product.products(for: TipJar.tipIDs)) ?? []
            offline = products.isEmpty
        }
        .onInAppPurchaseCompletion { _, result in
            if case .success(.success(.verified(let transaction))) = result {
                await transaction.finish()
                withAnimation(.spring(duration: 0.4)) { thanked = true }
            }
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
