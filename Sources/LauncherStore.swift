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
    @Published var showAllProjects = false
    @Published var lastLaunchAt: String? {
        didSet { persistState() }
    }
    @Published var lastLaunchPreset: [PresetProjectState]? {
        didSet { persistState() }
    }
    @Published private(set) var liveProjectStates: [PresetProjectState] = []
    @Published private(set) var liveWindowCount = 0
    @Published private(set) var liveTargetCounts: [LaunchTarget: Int] = [:]
    @Published var statusMessage = "Ready."
    @Published var alertMessage: String?

    private let stateURL: URL
    private let encoder = JSONEncoder()
    private let isoFormatter = ISO8601DateFormatter()
    private var isRestoring = false
    private var liveRefreshTimer: Timer?

    init() {
        self.stateURL = LauncherStore.makeStateURL()

        let restoredState = LauncherStore.loadState(from: stateURL)
        self.projects = LauncherStore.mergeProjects(
            restored: restoredState?.projects ?? [],
            discovered: DefaultProjects.all
        )
        self.defaultLaunchTarget = restoredState?.defaultLaunchTarget ?? .claude
        self.presets = restoredState?.presets ?? []
        self.lastLaunchAt = restoredState?.lastLaunchAt
        self.lastLaunchPreset = restoredState?.lastLaunchPreset

        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        if restoredState == nil {
            persistState()
        }

        refreshLiveSessions()
        startLiveRefreshTimer()
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
            return "Launch 0 Windows"
        case 1:
            return "Launch 1 Window"
        default:
            return "Launch \(selectedCount) Windows"
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

    var currentSetSummary: String {
        guard liveWindowCount > 0 else {
            return "No live windows detected"
        }

        let pieces = LaunchTarget.allCases
            .filter { liveTargetCounts[$0] != nil }
            .map { target in
                "\(target.displayName) \(liveTargetCounts[target] ?? 0)"
            }

        let projectCount = Set(liveProjectStates.map(\.projectID)).count
        return "\(liveWindowCount) live windows • \(projectCount) projects • " + pieces.joined(separator: " • ")
    }

    var hasLastLaunchPreset: Bool {
        guard let lastLaunchPreset else { return false }
        return !lastLaunchPreset.isEmpty
    }

    var lastLaunchSummary: String {
        guard let lastLaunchPreset else {
            return "No launch captured yet"
        }

        let count = lastLaunchPreset.filter(\.isEnabled).count
        if count == 0 {
            return "No projects in last launch"
        }

        return "\(count) selected • \(lastLaunchDescription)"
    }

    func resetToStarterList() {
        apply(states: projectStates(from: DefaultProjects.all))
        statusMessage = "Applied starter list."
    }

    func applyCurrentSet() {
        guard !liveProjectStates.isEmpty else { return }
        apply(states: dedupedProjectStates(liveProjectStates))
        statusMessage = "Applied current set."
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
            projects: currentPresetSource()
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
            markProjectsAsSeen(selection.map(\.id), at: lastLaunchAt, overwrite: true)
            statusMessage = "Launched \(selection.count) project" + (selection.count == 1 ? "." : "s.")
        } catch {
            alertMessage = error.localizedDescription
            statusMessage = "Launch failed."
        }
    }

    var visibleProjectIDs: [String] {
        let relevantIDs = Set(currentRelevantProjectIDs())
        return projects.compactMap { project in
            if showAllProjects || relevantIDs.contains(project.id) {
                return project.id
            }
            return nil
        }
    }

    var hiddenProjectCount: Int {
        max(projects.count - visibleProjectIDs.count, 0)
    }

    func binding(for projectID: String) -> Binding<LaunchProject> {
        guard let index = projects.firstIndex(where: { $0.id == projectID }) else {
            fatalError("Missing project binding for \(projectID)")
        }

        return Binding(
            get: { self.projects[index] },
            set: { self.projects[index] = $0 }
        )
    }

    private func currentProjectStates() -> [PresetProjectState] {
        projectStates(from: projects)
    }

    private func currentPresetSource() -> [PresetProjectState] {
        if !liveProjectStates.isEmpty {
            return dedupedProjectStates(liveProjectStates)
        }
        return currentProjectStates()
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

    private func dedupedProjectStates(_ states: [PresetProjectState]) -> [PresetProjectState] {
        var seen = Set<String>()
        var result: [PresetProjectState] = []

        for state in states {
            guard !seen.contains(state.projectID) else { continue }
            seen.insert(state.projectID)
            result.append(state)
        }

        return result
    }

    private func apply(states: [PresetProjectState]) {
        isRestoring = true
        let stateByID = Dictionary(uniqueKeysWithValues: states.map { ($0.projectID, $0) })
        projects = projects.map { project in
            guard let presetState = stateByID[project.id] else {
                var updated = project
                updated.isEnabled = false
                return updated
            }
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

    private static func mergeProjects(
        restored: [LaunchProject],
        discovered: [LaunchProject]
    ) -> [LaunchProject] {
        guard !restored.isEmpty else {
            return discovered
        }

        let restoredIDs = Set(restored.map(\.id))
        let newProjects = discovered.filter { !restoredIDs.contains($0.id) }
        return restored + newProjects
    }

    private func currentRelevantProjectIDs() -> [String] {
        var explicitIDs = Set<String>()
        var seenIDs = Set<String>()

        for project in projects where project.isEnabled {
            explicitIDs.insert(project.id)
        }

        for state in liveProjectStates where state.isEnabled {
            explicitIDs.insert(state.projectID)
        }

        for state in lastLaunchPreset ?? [] where state.isEnabled {
            explicitIDs.insert(state.projectID)
        }

        for preset in presets {
            for state in preset.projects where state.isEnabled {
                explicitIDs.insert(state.projectID)
            }
        }

        for project in projects where project.lastSeenAt != nil {
            if !isAuxiliaryProjectVariant(project.id) {
                seenIDs.insert(project.id)
            }
        }

        let ids = explicitIDs.union(seenIDs)
        return projects.compactMap { ids.contains($0.id) ? $0.id : nil }
    }

    // Keep coordination/worktree variants out of the default list unless they are explicitly active.
    private func isAuxiliaryProjectVariant(_ projectID: String) -> Bool {
        projectID.hasSuffix("-coordination") || projectID.hasSuffix("-worktrees")
    }

    private func startLiveRefreshTimer() {
        liveRefreshTimer?.invalidate()
        liveRefreshTimer = Timer.scheduledTimer(withTimeInterval: 8, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.refreshLiveSessions()
            }
        }
    }

    private func refreshLiveSessions() {
        let discovery = SessionDiscovery.discover(homeDirectory: NSHomeDirectory())
        mergeLiveProjectsIfNeeded(from: discovery.sessions)
        let normalizedStates = supplementedLiveProjectStates(
            from: normalizedLiveProjectStates(from: discovery.sessions),
            targetCounts: discovery.targetCounts
        )

        liveWindowCount = discovery.totalWindowCount
        liveTargetCounts = discovery.targetCounts
        liveProjectStates = normalizedStates
        syncProjectsToLiveCurrentSet(normalizedStates)
    }

    private func mergeLiveProjectsIfNeeded(from sessions: [LiveSession]) {
        let knownIDs = Set(projects.map(\.id))
        var pendingIDs = Set<String>()
        let newProjects = sessions.compactMap { session -> LaunchProject? in
            guard !knownIDs.contains(session.projectID), pendingIDs.insert(session.projectID).inserted else { return nil }
            return LaunchProject(
                id: session.projectID,
                name: session.projectName,
                path: session.projectPath,
                isEnabled: false,
                launchTarget: session.launchTarget,
                lastSeenAt: isoFormatter.string(from: Date())
            )
        }

        if !newProjects.isEmpty {
            projects.append(contentsOf: newProjects)
        }

        let liveIDs = Set(sessions.map(\.projectID))
        guard !liveIDs.isEmpty else { return }
        markProjectsAsSeen(Array(liveIDs), at: isoFormatter.string(from: Date()), overwrite: false)
    }

    private func markProjectsAsSeen(_ ids: [String], at timestamp: String?, overwrite: Bool) {
        guard let timestamp else { return }
        let idSet = Set(ids)
        guard !idSet.isEmpty else { return }

        var didChange = false
        let updatedProjects = projects.map { project in
            guard idSet.contains(project.id) else { return project }
            guard overwrite || project.lastSeenAt == nil else { return project }
            guard project.lastSeenAt != timestamp else { return project }

            var updated = project
            updated.lastSeenAt = timestamp
            didChange = true
            return updated
        }

        if didChange {
            projects = updatedProjects
        }
    }

    private func normalizedLiveProjectStates(from sessions: [LiveSession]) -> [PresetProjectState] {
        let grouped = Dictionary(grouping: sessions, by: \.projectID)

        return projects.compactMap { project in
            guard let projectSessions = grouped[project.id], !projectSessions.isEmpty else {
                return nil
            }

            return PresetProjectState(
                projectID: project.id,
                isEnabled: true,
                launchTarget: dominantLaunchTarget(
                    for: projectSessions.map(\.launchTarget),
                    preferred: project.launchTarget
                )
            )
        }
    }

    private func supplementedLiveProjectStates(
        from baseStates: [PresetProjectState],
        targetCounts: [LaunchTarget: Int]
    ) -> [PresetProjectState] {
        var results = baseStates
        var mappedIDs = Set(baseStates.map(\.projectID))
        let mappedCounts = Dictionary(baseStates.map { ($0.launchTarget, 1) }, uniquingKeysWith: +)

        let recentEnabledProjects = projects
            .filter { $0.isEnabled && !mappedIDs.contains($0.id) }
            .sorted { lhs, rhs in
                (lhs.lastSeenAt ?? "") > (rhs.lastSeenAt ?? "")
            }

        for target in LaunchTarget.allCases {
            let deficit = max((targetCounts[target] ?? 0) - (mappedCounts[target] ?? 0), 0)
            guard deficit > 0 else { continue }

            let candidates = recentEnabledProjects.filter { project in
                !mappedIDs.contains(project.id) && resolvedTarget(for: project) == target
            }

            for project in candidates.prefix(deficit) {
                results.append(
                    PresetProjectState(
                        projectID: project.id,
                        isEnabled: true,
                        launchTarget: target
                    )
                )
                mappedIDs.insert(project.id)
            }
        }

        return results
    }

    private func dominantLaunchTarget(
        for targets: [LaunchTarget],
        preferred: LaunchTarget
    ) -> LaunchTarget {
        let counts = Dictionary(targets.map { ($0, 1) }, uniquingKeysWith: +)
        guard let highestCount = counts.values.max() else {
            return preferred
        }

        let candidates = counts
            .filter { $0.value == highestCount }
            .map(\.key)

        if candidates.contains(preferred) {
            return preferred
        }

        return LaunchTarget.allCases.first(where: candidates.contains) ?? preferred
    }

    private func syncProjectsToLiveCurrentSet(_ states: [PresetProjectState]) {
        isRestoring = true
        let stateByID = Dictionary(uniqueKeysWithValues: states.map { ($0.projectID, $0) })

        projects = projects.map { project in
            var updated = project
            if let liveState = stateByID[project.id] {
                updated.isEnabled = liveState.isEnabled
                updated.launchTarget = liveState.launchTarget
            } else {
                updated.isEnabled = false
            }
            return updated
        }

        isRestoring = false
    }
}

private struct LiveSession {
    let projectID: String
    let projectName: String
    let projectPath: String
    let launchTarget: LaunchTarget
}

private struct SessionDiscoveryResult {
    let totalWindowCount: Int
    let targetCounts: [LaunchTarget: Int]
    let sessions: [LiveSession]
}

private enum SessionDiscovery {
    private static let homeProjectsMarker = "/projects/"

    static func discover(homeDirectory: String) -> SessionDiscoveryResult {
        let ttyTargets = discoverTTYTargets()
        guard !ttyTargets.isEmpty else {
            return SessionDiscoveryResult(totalWindowCount: 0, targetCounts: [:], sessions: [])
        }

        let sessionRecords = discoverITermSessions()
        let projectPrefix = homeDirectory + homeProjectsMarker
        let targetCounts = Dictionary(ttyTargets.values.map { ($0, 1) }, uniquingKeysWith: +)

        let sessions: [LiveSession] = sessionRecords.compactMap { record in
            guard
                let target = ttyTargets[record.tty],
                let match = projectMatch(in: record.tail, projectPrefix: projectPrefix)
            else {
                return nil
            }

            return LiveSession(
                projectID: match.projectID,
                projectName: prettyName(for: match.projectID),
                projectPath: match.projectPath,
                launchTarget: target
            )
        }

        return SessionDiscoveryResult(
            totalWindowCount: ttyTargets.count,
            targetCounts: targetCounts,
            sessions: sessions
        )
    }

    private static func discoverTTYTargets() -> [String: LaunchTarget] {
        let command = """
        ps -axo tty=,comm=,args= | egrep '(ttys|claude|opencode|gemini|codex)'
        """
        guard let output = run(command) else { return [:] }

        var mapping: [String: LaunchTarget] = [:]
        for line in output.split(separator: "\n") {
            let text = String(line)
            guard let tty = text.split(whereSeparator: \.isWhitespace).first.map(String.init), tty.hasPrefix("ttys") else {
                continue
            }

            if text.contains(" claude") || text.contains("\tclaude") || text.contains("claude ") {
                mapping["/dev/\(tty)"] = .claude
            } else if text.contains(" opencode") || text.contains("\topencode") || text.contains("opencode ") {
                mapping["/dev/\(tty)"] = .opencode
            } else if text.contains("/opt/homebrew/bin/gemini") || text.contains(" gemini") {
                mapping["/dev/\(tty)"] = .gemini
            } else if text.contains("/codex/") || text.contains(" codex") || text.contains("/opt/homebrew/bin/codex") {
                mapping["/dev/\(tty)"] = .codex
            }
        }

        return mapping
    }

    private static func discoverITermSessions() -> [ITermSessionRecord] {
        let script = """
        set fieldSep to ASCII character 30
        set recordSep to ASCII character 31
        tell application id "com.googlecode.iterm2"
          set outputRecords to {}
          repeat with w in windows
            repeat with t in tabs of w
              repeat with s in sessions of t
                set sessionName to ""
                set sessionTTY to ""
                set sessionTail to ""
                try
                  set sessionName to name of s as text
                end try
                try
                  set sessionTTY to tty of s as text
                end try
                try
                  set sessionContents to contents of s as text
                  set sessionLength to length of sessionContents
                  if sessionLength > 1600 then
                    set sessionTail to text (sessionLength - 1599) thru sessionLength of sessionContents
                  else
                    set sessionTail to sessionContents
                  end if
                end try
                set end of outputRecords to sessionName & fieldSep & sessionTTY & fieldSep & sessionTail
              end repeat
            end repeat
          end repeat
        end tell
        set AppleScript's text item delimiters to recordSep
        set joinedText to outputRecords as text
        set AppleScript's text item delimiters to ""
        return joinedText
        """

        guard let output = run("/usr/bin/osascript <<'APPLESCRIPT'\n\(script)\nAPPLESCRIPT") else {
            return []
        }

        return output
            .split(separator: Character("\u{1F}"))
            .compactMap { record -> ITermSessionRecord? in
                let fields = String(record).split(separator: Character("\u{1E}"), maxSplits: 2, omittingEmptySubsequences: false)
                guard fields.count >= 3 else { return nil }
                return ITermSessionRecord(
                    name: String(fields[0]),
                    tty: String(fields[1]),
                    tail: String(fields[2])
                )
            }
    }

    private static func projectMatch(in text: String, projectPrefix: String) -> (projectID: String, projectPath: String)? {
        let escapedPrefix = NSRegularExpression.escapedPattern(for: projectPrefix)
        let pattern = escapedPrefix + #"([^/\s]+)"#

        guard
            let regex = try? NSRegularExpression(pattern: pattern),
            let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
            let slugRange = Range(match.range(at: 1), in: text)
        else {
            return nil
        }

        let slug = String(text[slugRange])
        return (slug, projectPrefix + slug)
    }

    private static func prettyName(for slug: String) -> String {
        slug
            .split(separator: "-")
            .map { part in
                let text = String(part)
                return text.prefix(1).uppercased() + text.dropFirst()
            }
            .joined(separator: " ")
    }

    private static func run(_ command: String) -> String? {
        let process = Process()
        let outputPipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = ["-lc", command]
        process.standardOutput = outputPipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else { return nil }
            let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8)
        } catch {
            return nil
        }
    }
}

private struct ITermSessionRecord {
    let name: String
    let tty: String
    let tail: String
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
