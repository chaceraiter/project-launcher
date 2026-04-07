# Project Launcher

Project Launcher is a native SwiftUI macOS app for restoring a saved working set of CLI sessions after a restart.

It is intentionally simple: pick the projects you want back, choose what each project should open with, save named presets, and launch the whole set in one shot.

## Features

- Native SwiftUI desktop app for macOS 14+
- Per-project launch target rows
- Global default launch target plus per-project overrides
- Named presets and automatic last-launch recall
- Persistent saved state in Application Support
- iTerm-first terminal launching with Terminal fallback
- Custom bundled app icon generated locally during packaging
- Opinionated default project paths under `~/projects`

## Supported launch targets

- Claude Code
- Codex CLI
- Gemini CLI
- OpenCode
- Cursor
- VS Code
- None
- Default

## Run in development

```bash
cd ~/projects/project-launcher
swift run
```

## Build a standalone app

```bash
cd ~/projects/project-launcher
./build-app.sh
```

The built app bundle lands in `dist/Project Launcher.app`.

## Install locally

Do not run the built app from Desktop. macOS treats Desktop as a protected folder, so launching an unsigned app from there can trigger ugly file-access prompts.

Install the app to `~/Applications` instead:

```bash
cd ~/projects/project-launcher
./scripts/install_app.sh
open ~/Applications/"Project Launcher.app"
```

## Default project list

The starter list assumes your repos live under `~/projects`.
If you want a different default set, edit `Sources/Models.swift`.

## Permissions

On first launch, macOS should ask for Automation access so the app can open iTerm or Terminal windows for your selected projects.

## CI

GitHub Actions runs a macOS build on pushes and pull requests using `.github/workflows/ci.yml`.

## License

MIT
