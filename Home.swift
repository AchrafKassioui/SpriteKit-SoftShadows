import SwiftUI

@main struct MyApp: App {
    var body: some Scene {
        WindowGroup {
            HomeView()
        }
    }
}

struct HomeView: View {
    var body: some View {
        Text("Hello, world!")
            .padding()
    }
}
