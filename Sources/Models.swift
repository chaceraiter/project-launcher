import Foundation

enum AssistantKind: String, CaseIterable, Codable, Identifiable {
    case claude
    case codex
    case gemini
    case opencode

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .claude:
            return "Claude Code"
        case .codex:
            return "Codex CLI"
        case .gemini:
            return "Gemini"
        case .opencode:
            return "OpenCode"
        }
    }

    var command: String { rawValue }

    var tintHex: String {
        switch self {
        case .claude:
            return "#2E6A57"
        case .codex:
            return "#205A8D"
        case .gemini:
            return "#9A5A1A"
        case .opencode:
            return "#7D3F7A"
        }
    }
}

enum EditorKind: String, CaseIterable, Codable, Identifiable {
    case none
    case cursor
    case vscode

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .none:
            return "None"
        case .cursor:
            return "Cursor"
        case .vscode:
            return "VS Code"
        }
    }

    var appName: String? {
        switch self {
        case .none:
            return nil
        case .cursor:
            return "Cursor"
        case .vscode:
            return "Visual Studio Code"
        }
    }
}

struct LaunchProject: Identifiable, Codable, Equatable {
    let id: String
    var name: String
    var path: String
    var isEnabled: Bool
    var assistant: AssistantKind
    var editor: EditorKind
}

struct PersistedState: Codable {
    var lastLaunchAt: String?
    var projects: [LaunchProject]
}

enum DefaultProjects {
    static let all: [LaunchProject] = {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let projectsRoot = "\(home)/projects"

        return [
            LaunchProject(
                id: "infra-mgmt",
                name: "Infra Mgmt",
                path: "\(projectsRoot)/infra-mgmt",
                isEnabled: true,
                assistant: .claude,
                editor: .none
            ),
            LaunchProject(
                id: "portfolio-site",
                name: "Portfolio Site",
                path: "\(projectsRoot)/portfolio-site",
                isEnabled: true,
                assistant: .claude,
                editor: .none
            ),
            LaunchProject(
                id: "adaptive-mafia-game",
                name: "Mafia Game",
                path: "\(projectsRoot)/adaptive-mafia-game",
                isEnabled: true,
                assistant: .claude,
                editor: .none
            ),
            LaunchProject(
                id: "flappy-game",
                name: "Flappy Game",
                path: "\(projectsRoot)/flappy-game",
                isEnabled: true,
                assistant: .claude,
                editor: .none
            ),
            LaunchProject(
                id: "usage-meter",
                name: "Usage Meter",
                path: "\(projectsRoot)/usage-meter",
                isEnabled: true,
                assistant: .opencode,
                editor: .none
            ),
            LaunchProject(
                id: "evolution",
                name: "Evolution",
                path: "\(projectsRoot)/evolution",
                isEnabled: true,
                assistant: .gemini,
                editor: .none
            ),
            LaunchProject(
                id: "fluidics-test",
                name: "Fluidics Test",
                path: "\(projectsRoot)/fluidics-test",
                isEnabled: true,
                assistant: .codex,
                editor: .none
            ),
        ]
    }()
}
