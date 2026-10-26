import SwiftUI

@main
struct SooFunnyApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct ContentView: View {
    @State private var session: ColoringSession?

    var body: some View {
        HomeView { image in
            session = ColoringSession(image: image)
        }
        .fullScreenCover(item: $session) { session in
            ColoringView(session: session)
        }
    }
}
