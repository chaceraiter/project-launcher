import Foundation
import SwiftUI

@MainActor
final class LauncherStore: ObservableObject {
    @Published var projects: [LaunchProject]
    @Published var lastLaunchAt: String?
    @Published var statusMessage = "Ready to launch project sessions."
    @Published var alertMessage: String?

    private let stateURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let isoFormatter = ISO8601DateFormatter()
    private var isRestoring = false

    init() {
        self.stateURL = LauncherStore.makeStateURL()

        let restoredState = LauncherStore.loadState(from: stateURL)
        self.projects = restoredState?.projects ?? DefaultProjects.all
        self.lastLaunchAt = restoredState?.lastLaunchAt

        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        decoder.dateDecodingStrategy = .iso8601

        if restoredState == nil {
            persistState()
        }
    }

    var selectedProjects: [LaunchProject] {
        projects.filter(\.isEnabled)
    }

    var selectedCount: Int {
        selectedProjects.count
    }

    var launchButtonTitle: String {
        let count = selectedCount
        guard count > 0 else { return "Launch Selected" }
        return count == 1 ? "Launch 1 Session" : "Launch \(count) Sessions"
    }

    var lastLaunchDescription: String {
        guard let lastLaunchAt else {
            return "Never launched from this app yet."
        }

        guard let date = isoFormatter.date(from: lastLaunchAt) else {
            return lastLaunchAt
        }

        return date.formatted(
            .dateTime
                .month(.abbreviated)
                .day()
                .year()
                .hour(.defaultDigits(amPM: .abbreviated))
                .minute()
                .second()
        )
    }

    var summaryChips: [String] {
        guard !selectedProjects.isEmpty else {
            return ["No projects selected"]
        }

        var chips = ["\(selectedProjects.count) selected"]
        for assistant in AssistantKind.allCases {
            let count = selectedProjects.filter { $0.assistant == assistant }.count
            if count > 0 {
                chips.append("\(assistant.displayName): \(count)")
            }
        }
        return chips
    }

    func resetDefaults() {
        isRestoring = true
        projects = DefaultProjects.all
        isRestoring = false
        persistState()
        statusMessage = "Restored the default launch set."
    }

    func persistState() {
        guard !isRestoring else { return }

        let state = PersistedState(lastLaunchAt: lastLaunchAt, projects: projects)
        do {
            let folder = stateURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let data = try encoder.encode(state)
            try data.write(to: stateURL, options: .atomic)
        } catch {
            statusMessage = "State save failed: \(error.localizedDescription)"
        }
    }

    func launchSelected() {
        let selection = selectedProjects
        guard !selection.isEmpty else {
            alertMessage = "Select at least one project first."
            return
        }

        do {
            try validate(selection)

            for project in selection {
                if project.editor != .none {
                    try launchEditor(project)
                }
            }

            for project in selection {
                try launchAssistant(project)
            }

            lastLaunchAt = isoFormatter.string(from: Date())
            persistState()
            statusMessage = "Launched \(selection.count) session" + (selection.count == 1 ? "." : "s.")
        } catch {
            alertMessage = error.localizedDescription
            statusMessage = "Launch failed."
        }
    }

    func projectChanged() {
        persistState()
    }

    private func validate(_ projects: [LaunchProject]) throws {
        for project in projects {
            guard FileManager.default.fileExists(atPath: project.path) else {
                throw LaunchError.generic("Missing project folder for \(project.name):\n\(project.path)")
            }

            guard commandExists(project.assistant.command) else {
                throw LaunchError.generic("Missing CLI command for \(project.assistant.displayName).")
            }

            if let appName = project.editor.appName, !applicationExists(named: appName) {
                throw LaunchError.generic("Missing editor app for \(project.editor.displayName).")
            }
        }

        if !terminalHostExists {
            throw LaunchError.generic("Neither iTerm nor Terminal.app is available.")
        }
    }

    private var terminalHostExists: Bool {
        FileManager.default.fileExists(atPath: "/Applications/iTerm.app") ||
        FileManager.default.fileExists(atPath: "/System/Applications/Utilities/Terminal.app")
    }

    private func commandExists(_ command: String) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = ["-lc", "command -v \(command) >/dev/null 2>&1"]

        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }

    private func applicationExists(named name: String) -> Bool {
        let commonPaths = [
            "/Applications/\(name).app",
            "\(NSHomeDirectory())/Applications/\(name).app",
        ]

        return commonPaths.contains(where: FileManager.default.fileExists(atPath:))
    }

    private func launchEditor(_ project: LaunchProject) throws {
        guard let appName = project.editor.appName else { return }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = ["-a", appName, project.path]
        try process.run()
    }

    private func launchAssistant(_ project: LaunchProject) throws {
        let quotedPath = project.path.replacingOccurrences(of: "'", with: "'\"'\"'")
        let shellCommand = "cd '\(quotedPath)' && clear && \(project.assistant.command)"

        let script: String
        if FileManager.default.fileExists(atPath: "/Applications/iTerm.app") {
            script = """
            on run argv
              set shellCommand to item 1 of argv
              tell application "iTerm"
                activate
                set newWindow to (create window with default profile)
                tell current session of current tab of newWindow
                  write text shellCommand
                end tell
              end tell
            end run
            """
        } else {
            script = """
            on run argv
              set shellCommand to item 1 of argv
              tell application "Terminal"
                activate
                do script shellCommand
              end tell
            end run
            """
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script, shellCommand]
        try process.run()
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            throw LaunchError.generic("Could not open \(project.assistant.displayName) for \(project.name).")
        }
    }

    private static func makeStateURL() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return base
            .appendingPathComponent("ProjectLauncher", isDirectory: true)
            .appendingPathComponent("state.json")
    }

    private static func loadState(from url: URL) -> PersistedState? {
        guard
            let data = try? Data(contentsOf: url),
            let decoded = try? JSONDecoder().decode(PersistedState.self, from: data)
        else {
            return nil
        }

        return decoded
    }
}

enum LaunchError: LocalizedError {
    case generic(String)

    var errorDescription: String? {
        switch self {
        case .generic(let message):
            return message
        }
    }
}
