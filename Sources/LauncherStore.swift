import Foundation
import SwiftUI

@MainActor
final class LauncherStore: ObservableObject {
    @Published var projects: [LaunchProject] {
        didSet { persistState() }
    }
    @Published var defaultLaunchTarget: LaunchTarget {
        didSet { persistState() }
    }
    @Published var presets: [LaunchPreset] {
        didSet { persistState() }
    }
    @Published var presetDraft = ""
    @Published var lastLaunchAt: String? {
        didSet { persistState() }
    }
    @Published var lastLaunchPreset: [PresetProjectState]? {
        didSet { persistState() }
    }
    @Published var statusMessage = "Ready."
    @Published var alertMessage: String?

    private let stateURL: URL
    private let encoder = JSONEncoder()
    private let isoFormatter = ISO8601DateFormatter()
    private var isRestoring = false

    init() {
        self.stateURL = LauncherStore.makeStateURL()

        let restoredState = LauncherStore.loadState(from: stateURL)
        self.projects = restoredState?.projects ?? DefaultProjects.all
        self.defaultLaunchTarget = restoredState?.defaultLaunchTarget ?? .claude
        self.presets = restoredState?.presets ?? []
        self.lastLaunchAt = restoredState?.lastLaunchAt
        self.lastLaunchPreset = restoredState?.lastLaunchPreset

        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

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
        switch selectedCount {
        case 0:
            return "Launch"
        case 1:
            return "Launch 1"
        default:
            return "Launch \(selectedCount)"
        }
    }

    var lastLaunchDescription: String {
        guard let lastLaunchAt else {
            return "Never"
        }

        guard let date = isoFormatter.date(from: lastLaunchAt) else {
            return lastLaunchAt
        }

        return date.formatted(
            .dateTime
                .month(.abbreviated)
                .day()
                .hour(.defaultDigits(amPM: .abbreviated))
                .minute()
        )
    }

    var summaryText: String {
        guard !selectedProjects.isEmpty else {
            return "No projects selected"
        }

        let grouped = Dictionary(grouping: selectedProjects, by: { resolvedTarget(for: $0).displayName })
        let pieces = grouped
            .keys
            .sorted()
            .map { key in
                let count = grouped[key]?.count ?? 0
                return "\(key) \(count)"
            }

        return "\(selectedProjects.count) selected • " + pieces.joined(separator: " • ")
    }

    var defaultPreset: LaunchPreset {
        LaunchPreset(id: "default", name: "Default", projects: projectStates(from: DefaultProjects.all))
    }

    var hasLastLaunchPreset: Bool {
        guard let lastLaunchPreset else { return false }
        return !lastLaunchPreset.isEmpty
    }

    func resetToDefaultPreset() {
        apply(states: defaultPreset.projects)
        statusMessage = "Applied default preset."
    }

    func applyLastLaunchPreset() {
        guard let lastLaunchPreset else { return }
        apply(states: lastLaunchPreset)
        statusMessage = "Applied last launch."
    }

    func applyPreset(_ preset: LaunchPreset) {
        apply(states: preset.projects)
        statusMessage = "Applied \(preset.name)."
    }

    func saveCurrentPreset() {
        let rawName = presetDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !rawName.isEmpty else {
            alertMessage = "Enter a preset name first."
            return
        }

        let normalized = rawName.lowercased()
        let newPreset = LaunchPreset(
            id: normalized.replacingOccurrences(of: " ", with: "-"),
            name: rawName,
            projects: currentProjectStates()
        )

        if let existingIndex = presets.firstIndex(where: { $0.name.lowercased() == normalized }) {
            presets[existingIndex] = newPreset
            statusMessage = "Updated preset \(rawName)."
        } else {
            presets.append(newPreset)
            presets.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            statusMessage = "Saved preset \(rawName)."
        }

        presetDraft = ""
    }

    func deletePreset(_ preset: LaunchPreset) {
        presets.removeAll { $0.id == preset.id }
        statusMessage = "Deleted preset \(preset.name)."
    }

    func resolvedTarget(for project: LaunchProject) -> LaunchTarget {
        project.launchTarget == .default ? defaultLaunchTarget : project.launchTarget
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
                try launch(project: project, target: resolvedTarget(for: project))
            }

            let snapshot = currentProjectStates()
            lastLaunchPreset = snapshot
            lastLaunchAt = isoFormatter.string(from: Date())
            statusMessage = "Launched \(selection.count) project" + (selection.count == 1 ? "." : "s.")
        } catch {
            alertMessage = error.localizedDescription
            statusMessage = "Launch failed."
        }
    }

    private func currentProjectStates() -> [PresetProjectState] {
        projectStates(from: projects)
    }

    private func projectStates(from source: [LaunchProject]) -> [PresetProjectState] {
        source.map {
            PresetProjectState(
                projectID: $0.id,
                isEnabled: $0.isEnabled,
                launchTarget: $0.launchTarget
            )
        }
    }

    private func apply(states: [PresetProjectState]) {
        isRestoring = true
        let stateByID = Dictionary(uniqueKeysWithValues: states.map { ($0.projectID, $0) })
        projects = projects.map { project in
            guard let presetState = stateByID[project.id] else { return project }
            var updated = project
            updated.isEnabled = presetState.isEnabled
            updated.launchTarget = presetState.launchTarget
            return updated
        }
        isRestoring = false
        persistState()
    }

    private func persistState() {
        guard !isRestoring else { return }

        let state = PersistedState(
            lastLaunchAt: lastLaunchAt,
            defaultLaunchTarget: defaultLaunchTarget,
            projects: projects,
            presets: presets,
            lastLaunchPreset: lastLaunchPreset
        )

        do {
            let folder = stateURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let data = try encoder.encode(state)
            try data.write(to: stateURL, options: .atomic)
        } catch {
            statusMessage = "State save failed: \(error.localizedDescription)"
        }
    }

    private func validate(_ projects: [LaunchProject]) throws {
        var launchableCount = 0
        var needsTerminal = false

        for project in projects {
            guard FileManager.default.fileExists(atPath: project.path) else {
                throw LaunchError.generic("Missing project folder for \(project.name):\n\(project.path)")
            }

            let target = resolvedTarget(for: project)
            if target == .none {
                continue
            }

            launchableCount += 1

            if let command = target.command {
                needsTerminal = true
                if !commandExists(command) {
                    throw LaunchError.generic("Missing command for \(target.displayName).")
                }
            }

            if let appName = target.appName, !applicationExists(named: appName) {
                throw LaunchError.generic("Missing app for \(target.displayName).")
            }
        }

        if launchableCount == 0 {
            throw LaunchError.generic("Every selected project is set to None.")
        }

        if needsTerminal && !terminalHostExists {
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

    private func launch(project: LaunchProject, target: LaunchTarget) throws {
        if let appName = target.appName {
            try launchApp(name: appName, path: project.path)
            return
        }

        if let command = target.command {
            try launchTerminal(command: command, path: project.path)
        }
    }

    private func launchApp(name: String, path: String) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = ["-a", name, path]
        try process.run()
    }

    private func launchTerminal(command: String, path: String) throws {
        let quotedPath = path.replacingOccurrences(of: "'", with: "'\"'\"'")
        let shellCommand = "cd '\(quotedPath)' && clear && \(command)"

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
            throw LaunchError.generic("Could not launch \(command) in \(path).")
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
