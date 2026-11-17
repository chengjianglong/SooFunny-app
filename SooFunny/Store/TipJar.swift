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

/// The tips, straight away. The App Store's own purchase sheet asks for Face ID or the account
/// password before anything is paid, so there's no extra grown-up check.
struct SupportView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(LearningLanguage.key) private var language: LearningLanguage = .english
    @State private var thanked = false
    /// True when the App Store couldn't be reached (SooFunny is often used offline).
    @State private var offline = false

    var body: some View {
        NavigationStack {
            tips
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(language.pick("Close", "关闭")) { dismiss() }
                }
            }
        }
    }

    private var tips: some View {
        ScrollView {
            VStack(spacing: 18) {
                Text(thanked ? "💛" : "💖").font(.system(size: 64))
                Text(thanked ? language.pick("Thank you!", "谢谢你！", separator: "\n") : language.pick("Support SooFunny", "支持 SooFunny", separator: "\n"))
                    .font(.system(size: 34, weight: .black, design: .rounded))
                    .foregroundStyle(LinearGradient(colors: [.pink, .orange, .purple], startPoint: .leading, endPoint: .trailing))
                Text(thanked
                     ? language.pick("Your tip helps keep SooFunny maintained and growing, free for every family.",
                                     "你的打赏帮助 SooFunny 持续维护和成长，让每个家庭都能免费使用。", separator: "\n\n")
                     : language.pick("SooFunny is free for everyone, with no ads and no tracking. If your family enjoys it, a tip helps keep it maintained and add new things to learn.",
                                     "SooFunny 对所有人免费，没有广告，也不追踪。如果你的家人喜欢它，打赏可以帮助我们维护应用、增加新的学习内容。",
                                     separator: "\n\n"))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                if offline {
                    Label(language.pick("Tips need an internet connection. Please try again when you're online.", "打赏需要连接网络，请联网后再试。",
                                        separator: "\n"), systemImage: "wifi.slash")
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
                Text(language.pick("Tips are optional, one-time payments. They don't unlock anything: every feature is already free.",
                                   "打赏是自愿的一次性付款，不会解锁任何内容：所有功能本来就免费。", separator: "\n"))
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
/// links that leave the app and the Research Lab.
struct ParentalGate: View {
    let reason: String
    let onPass: () -> Void

    @State private var question = ParentalGate.makeQuestion()
    @AppStorage(LearningLanguage.key) private var language: LearningLanguage = .english
    @State private var answer = ""
    @State private var wrong = false
    @FocusState private var focused: Bool

    static func makeQuestion() -> (Int, Int) { (Int.random(in: 12...19), Int.random(in: 6...9)) }

    var body: some View {
        ScrollView {
        VStack(spacing: 18) {
            Text("👨‍👩‍👧").font(.system(size: 64))
            Text(language.pick("Ask a grown-up", "请家长来", separator: "\n")).font(.largeTitle.weight(.heavy)).multilineTextAlignment(.center)
            Text(reason).foregroundStyle(.secondary)
            Text(language.pick("What is \(question.0) × \(question.1)?", "\(question.0) × \(question.1) 等于几？", separator: "\n"))
                .multilineTextAlignment(.center)
                .font(.title.weight(.bold).monospacedDigit())
            TextField(language.pick("Answer", "答案"), text: $answer)
                .keyboardType(.numberPad)
                .font(.title2.monospacedDigit())
                .multilineTextAlignment(.center)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 200)
                .focused($focused)
                .onSubmit(check)
            if wrong {
                Text(language.pick("That's not right. Try this one.", "不对哦，换一题试试。")).foregroundStyle(.red)
            }
            Button(language.pick("Continue", "继续"), action: check)
                .buttonStyle(.borderedProminent)
                .font(.headline)
                .disabled(answer.isEmpty)
        }
        .padding(32)
        .frame(maxWidth: 520)
        .frame(maxWidth: .infinity)
        .fixedSize(horizontal: false, vertical: true)
        }
        .scrollDismissesKeyboard(.never)
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
