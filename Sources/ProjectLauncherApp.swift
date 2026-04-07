import SwiftUI

@main
struct ProjectLauncherApp: App {
    @StateObject private var store = LauncherStore()

    var body: some Scene {
        WindowGroup("Project Launcher") {
            ContentView()
                .environmentObject(store)
                .frame(minWidth: 980, minHeight: 720)
        }
        .windowResizability(.contentMinSize)
        .defaultSize(width: 1120, height: 820)
    }
}
