import SwiftUI

/// Checks the App Store for a newer version of SooFunny and, when there is one, offers it.
///
/// The check asks Apple's public lookup service for the latest version number only; nothing about
/// the child or the device is sent. It runs at launch and when the app comes back to the front,
/// at most every few hours. "Not now" hides the reminder for that version for three days.
/// Opening the App Store leaves the app, so it is behind the grown-up check.
@MainActor
final class AppUpdateChecker: ObservableObject {
    static let shared = AppUpdateChecker()

    static let appStoreID = "6827777441"
    static let appStoreURL = URL(string: "itms-apps://apps.apple.com/app/id\(appStoreID)")!

    /// The newer version to offer, or nil.
    @Published var available: String?

    private let defaults: UserDefaults
    private let fetch: (URL) async throws -> Data
    private var checking = false

    static let checkInterval: TimeInterval = 6 * 60 * 60
    static let snoozeInterval: TimeInterval = 3 * 24 * 60 * 60

    enum Key {
        static let lastCheck = "updateLastCheck"
        static let snoozedVersion = "updateSnoozedVersion"
        static let snoozedUntil = "updateSnoozedUntil"
    }

    init(defaults: UserDefaults = .standard,
         fetch: @escaping (URL) async throws -> Data = { url in
             var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 15)
             request.setValue("application/json", forHTTPHeaderField: "Accept")
             return try await URLSession.shared.data(for: request).0
         }) {
        self.defaults = defaults
        self.fetch = fetch
    }

    nonisolated static var installedVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
    }

    /// Looks up the App Store version unless it was checked recently.
    func checkIfDue(installed: String = AppUpdateChecker.installedVersion, now: Date = .now, force: Bool = false) async {
        guard !checking else { return }
        var force = force
        #if DEBUG
        if defaults.string(forKey: "updateTestLatest") != nil { force = true }
        #endif
        if !force, let last = defaults.object(forKey: Key.lastCheck) as? Date,
           now.timeIntervalSince(last) < Self.checkInterval {
            return
        }
        checking = true
        defer { checking = false }
        guard let latest = await latestVersion() else { return }
        defaults.set(now, forKey: Key.lastCheck)
        available = Self.shouldOffer(latest: latest, installed: installed,
                                     snoozedVersion: defaults.string(forKey: Key.snoozedVersion),
                                     snoozedUntil: defaults.object(forKey: Key.snoozedUntil) as? Date,
                                     now: now) ? latest : nil
    }

    /// Hides the reminder for this version for a few days.
    func snooze(now: Date = .now) {
        guard let available else { return }
        defaults.set(available, forKey: Key.snoozedVersion)
        defaults.set(now.addingTimeInterval(Self.snoozeInterval), forKey: Key.snoozedUntil)
        self.available = nil
    }

    private func latestVersion() async -> String? {
        #if DEBUG
        // For trying the reminder: launch with `-updateTestLatest 9.9`.
        if let test = defaults.string(forKey: "updateTestLatest") { return test }
        #endif
        // The local storefront first (the app is in 175 countries and regions), then the default one.
        var urls: [URL] = []
        if let region = Locale.current.region?.identifier, region.count == 2 {
            urls.append(URL(string: "https://itunes.apple.com/lookup?id=\(Self.appStoreID)&country=\(region.lowercased())")!)
        }
        urls.append(URL(string: "https://itunes.apple.com/lookup?id=\(Self.appStoreID)")!)
        for url in urls {
            if let data = try? await fetch(url), let version = Self.version(fromLookup: data) {
                return version
            }
        }
        return nil
    }

    // MARK: - Pure helpers (tested)

    /// The version in an App Store lookup response.
    nonisolated static func version(fromLookup data: Data) -> String? {
        struct Response: Decodable {
            struct Result: Decodable { let version: String? }
            let results: [Result]
        }
        guard let response = try? JSONDecoder().decode(Response.self, from: data) else { return nil }
        return response.results.first?.version
    }

    /// True when `latest` is a higher version than `installed`, comparing each number in turn
    /// ("0.10" is newer than "0.9", and "1.0" is the same as "1").
    nonisolated static func isNewer(_ latest: String, than installed: String) -> Bool {
        func parts(_ v: String) -> [Int] {
            v.split(separator: ".").map { Int($0.prefix { $0.isNumber }) ?? 0 }
        }
        let a = parts(latest), b = parts(installed)
        for i in 0..<max(a.count, b.count) {
            let x = i < a.count ? a[i] : 0, y = i < b.count ? b[i] : 0
            if x != y { return x > y }
        }
        return false
    }

    nonisolated static func shouldOffer(latest: String, installed: String,
                                        snoozedVersion: String?, snoozedUntil: Date?, now: Date) -> Bool {
        guard isNewer(latest, than: installed) else { return false }
        if snoozedVersion == latest, let until = snoozedUntil, now < until { return false }
        return true
    }
}

/// The reminder: "A new version of SooFunny is ready", with Update (after the grown-up check) and Not now.
struct UpdateReminder: View {
    let version: String
    let onNotNow: () -> Void

    @AppStorage(LearningLanguage.key) private var language: LearningLanguage = .english
    @Environment(\.openURL) private var openURL
    @State private var showGate = false

    var body: some View {
        NavigationStack {
            Group {
                if showGate {
                    ParentalGate(reason: language.pick("Updating opens the App Store.", "更新会打开 App Store。", separator: "\n")) {
                        openURL(AppUpdateChecker.appStoreURL)
                        onNotNow()
                    }
                } else {
                    ScrollView {
                    VStack(spacing: 18) {
                        Text("🎉").font(.system(size: 56))
                        Text(language.pick("A new SooFunny is ready!", "SooFunny 有新版本啦！", separator: "\n"))
                            .font(.title.weight(.heavy))
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(language.pick("Update to version \(version) for the newest fun and fixes.",
                                           "更新到 \(version) 版，体验最新的内容和改进。", separator: "\n"))
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        Button(language.pick("Update", "更新")) { showGate = true }
                            .buttonStyle(.borderedProminent)
                            .font(.title3.weight(.bold))
                            .accessibilityIdentifier("updateNow")
                        Button(language.pick("Not now", "以后再说"), action: onNotNow)
                            .font(.headline)
                            .accessibilityIdentifier("updateNotNow")
                    }
                    .padding(24)
                    .frame(maxWidth: 520)
                    .frame(maxWidth: .infinity)
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(language.pick("Close", "关闭"), action: onNotNow)
                }
            }
        }
        .presentationDetents([.large])
    }
}
