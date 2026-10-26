import SwiftUI

@main
struct SooFunnyApp: App {
    init() {
        // Load the natural voice in the background so the first word plays quickly.
        NaturalVoiceEngine.shared.preload()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

/// Three tabs: Color (pictures to color), Words (the word browser) and Math. Settings is in the top bar.
struct ContentView: View {
    @State private var session: ColoringSession?
    @State private var showSettings = false

    var body: some View {
        TabView {
            NavigationStack {
                HomeView { image in
                    session = ColoringSession(image: image)
                }
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button { showSettings = true } label: { Label("Settings", systemImage: "gearshape") }
                    }
                }
                .sheet(isPresented: $showSettings) { SettingsView() }
            }
            .tabItem { Label("Color", systemImage: "paintpalette.fill") }

            WordsView()
                .tabItem { Label("Words", systemImage: "textformat.abc") }

            MathView()
                .tabItem { Label("Math", systemImage: "plus.forwardslash.minus") }
        }
        .fullScreenCover(item: $session) { session in
            ColoringView(session: session)
        }
    }
}
