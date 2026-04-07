import SwiftUI

@main
struct ProjectLauncherApp: App {
    @StateObject private var store = LauncherStore()

    var body: some Scene {
        WindowGroup("Project Launcher") {
            ContentView()
                .environmentObject(store)
                .frame(minWidth: 660, minHeight: 500)
        }
        .windowResizability(.contentMinSize)
        .defaultSize(width: 700, height: 560)
    }
}
