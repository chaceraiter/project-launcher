import Foundation

enum LaunchTarget: String, CaseIterable, Codable, Identifiable {
    case `default`
    case none
    case claude
    case codex
    case gemini
    case opencode
    case cursor
    case vscode

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .default:
            return "Default"
        case .none:
            return "None"
        case .claude:
            return "Claude Code"
        case .codex:
            return "Codex CLI"
        case .gemini:
            return "Gemini"
        case .opencode:
            return "OpenCode"
        case .cursor:
            return "Cursor"
        case .vscode:
            return "VS Code"
        }
    }

    var command: String? {
        switch self {
        case .claude, .codex, .gemini, .opencode:
            return rawValue
        case .default, .none, .cursor, .vscode:
            return nil
        }
    }

    var appName: String? {
        switch self {
        case .cursor:
            return "Cursor"
        case .vscode:
            return "Visual Studio Code"
        case .default, .none, .claude, .codex, .gemini, .opencode:
            return nil
        }
    }

    var isLaunchableDefault: Bool {
        self != .default && self != .none
    }

    static let defaultChoices: [LaunchTarget] = [.claude, .codex, .gemini, .opencode, .cursor, .vscode]
}

struct LaunchProject: Identifiable, Codable, Equatable {
    let id: String
    var name: String
    var path: String
    var isEnabled: Bool
    var launchTarget: LaunchTarget

    init(
        id: String,
        name: String,
        path: String,
        isEnabled: Bool,
        launchTarget: LaunchTarget
    ) {
        self.id = id
        self.name = name
        self.path = path
        self.isEnabled = isEnabled
        self.launchTarget = launchTarget
    }

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case path
        case isEnabled
        case launchTarget
        case assistant
        case editor
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        path = try container.decode(String.self, forKey: .path)
        isEnabled = try container.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? true

        if let target = try container.decodeIfPresent(LaunchTarget.self, forKey: .launchTarget) {
            launchTarget = target
            return
        }

        if let editor = try container.decodeIfPresent(LegacyEditorKind.self, forKey: .editor) {
            switch editor {
            case .cursor:
                launchTarget = .cursor
                return
            case .vscode:
                launchTarget = .vscode
                return
            case .none:
                break
            }
        }

        if let assistant = try container.decodeIfPresent(LegacyAssistantKind.self, forKey: .assistant) {
            switch assistant {
            case .claude:
                launchTarget = .claude
            case .codex:
                launchTarget = .codex
            case .gemini:
                launchTarget = .gemini
            case .opencode:
                launchTarget = .opencode
            }
        } else {
            launchTarget = .default
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(path, forKey: .path)
        try container.encode(isEnabled, forKey: .isEnabled)
        try container.encode(launchTarget, forKey: .launchTarget)
    }
}

struct PresetProjectState: Codable, Equatable {
    var projectID: String
    var isEnabled: Bool
    var launchTarget: LaunchTarget
}

struct LaunchPreset: Identifiable, Codable, Equatable {
    var id: String
    var name: String
    var projects: [PresetProjectState]
}

struct PersistedState: Codable {
    var lastLaunchAt: String?
    var defaultLaunchTarget: LaunchTarget
    var projects: [LaunchProject]
    var presets: [LaunchPreset]
    var lastLaunchPreset: [PresetProjectState]?

    init(
        lastLaunchAt: String?,
        defaultLaunchTarget: LaunchTarget,
        projects: [LaunchProject],
        presets: [LaunchPreset],
        lastLaunchPreset: [PresetProjectState]?
    ) {
        self.lastLaunchAt = lastLaunchAt
        self.defaultLaunchTarget = defaultLaunchTarget
        self.projects = projects
        self.presets = presets
        self.lastLaunchPreset = lastLaunchPreset
    }

    enum CodingKeys: String, CodingKey {
        case lastLaunchAt
        case defaultLaunchTarget
        case projects
        case presets
        case lastLaunchPreset
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        lastLaunchAt = try container.decodeIfPresent(String.self, forKey: .lastLaunchAt)
        defaultLaunchTarget = try container.decodeIfPresent(LaunchTarget.self, forKey: .defaultLaunchTarget) ?? .claude
        projects = try container.decodeIfPresent([LaunchProject].self, forKey: .projects) ?? DefaultProjects.all
        presets = try container.decodeIfPresent([LaunchPreset].self, forKey: .presets) ?? []
        lastLaunchPreset = try container.decodeIfPresent([PresetProjectState].self, forKey: .lastLaunchPreset)
    }
}

enum DefaultProjects {
    static let all: [LaunchProject] = {
        let fileManager = FileManager.default
        let projectsURL = fileManager.homeDirectoryForCurrentUser.appendingPathComponent("projects", isDirectory: true)

        guard let urls = try? fileManager.contentsOfDirectory(
            at: projectsURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        return urls
            .filter { url in
                let values = try? url.resourceValues(forKeys: [.isDirectoryKey])
                return values?.isDirectory == true
            }
            .sorted { $0.lastPathComponent.localizedCaseInsensitiveCompare($1.lastPathComponent) == .orderedAscending }
            .map { url in
                let slug = url.lastPathComponent
                return LaunchProject(
                    id: slug,
                    name: prettyName(for: slug),
                    path: url.path,
                    isEnabled: false,
                    launchTarget: .default
                )
            }
    }()

    private static func prettyName(for slug: String) -> String {
        slug
            .split(separator: "-")
            .map { part in
                let text = String(part)
                return text.prefix(1).uppercased() + text.dropFirst()
            }
            .joined(separator: " ")
    }
}

private enum LegacyAssistantKind: String, Codable {
    case claude
    case codex
    case gemini
    case opencode
}

private enum LegacyEditorKind: String, Codable {
    case none
    case cursor
    case vscode
}
