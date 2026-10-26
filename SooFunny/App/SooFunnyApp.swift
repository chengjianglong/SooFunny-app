import SwiftUI

@main
struct SooFunnyApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

/// Two tabs: Color (pictures to color) and Words (the word browser). Settings is in the top bar.
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
        }
        .fullScreenCover(item: $session) { session in
            ColoringView(session: session)
        }
    }
}
