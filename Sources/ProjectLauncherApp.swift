import SwiftUI

@main
struct ProjectLauncherApp: App {
    @StateObject private var store = LauncherStore()

    var body: some Scene {
        WindowGroup("Project Launcher") {
            ContentView()
                .environmentObject(store)
                .frame(minWidth: 720, minHeight: 540)
        }
        .windowResizability(.contentMinSize)
        .defaultSize(width: 780, height: 620)
    }
}
