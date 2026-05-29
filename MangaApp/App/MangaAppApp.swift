import SwiftUI

@main
struct MangaAppApp: App {
    @ObservedObject private var serviceProvider = ServiceProvider.shared

    var body: some Scene {
        WindowGroup {
            TabView {
                HomeView()
                    .tabItem {
                        Label("Home", systemImage: "house.fill")
                    }

                FavoritesView()
                    .tabItem {
                        Label("Favorites", systemImage: "heart.fill")
                    }

                VoiceAgentView()
                    .tabItem {
                        Label("AI Chat", systemImage: "waveform.circle.fill")
                    }

                SettingView()
                    .tabItem {
                        Label("Settings", systemImage: "gearshape.fill")
                    }
            }
            .tint(.pink)
            .id(serviceProvider.currentSource)
        }
    }
}
