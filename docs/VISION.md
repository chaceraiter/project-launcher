# Vision

Ideas that should shape the product beyond the current launcher workflow.

## Session Management

- Detect the real live session set from open terminal windows instead of relying only on saved UI state.
- Treat `Current Set` as a continuously updated snapshot of open agent windows and their associated projects.
- Keep `Last Launch` as a separate snapshot that records exactly what the app launched most recently.
- Allow saving the live `Current Set` directly as a named preset.
- Distinguish between total live agent windows and the subset that can be mapped cleanly back to project folders.
- Persist lightweight local "seen before" metadata so frequently used projects remain visible without exposing them in the public repo.

## Session Health

- Track cache age or last-activity age per agent/session.
- Surface stale sessions visually in the UI.
- Add optional keep-alive behavior when it is cheaper than forcing a cache refresh.
- Show which sessions are healthy, stale, disconnected, or missing.

## Agent State Dashboard

- Evolve the launcher into a lightweight agent-control surface, not just a one-shot window spawner.
- Show per-agent state such as:
  - awaiting permissions
  - idle
  - actively working
  - recently active within the last 5 minutes
  - stalled or unresponsive
  - missing window or closed session
- Show when a session is waiting on user action versus actually computing.
- Track a rolling "last active" timestamp per agent/window.
- Make the state model visible enough that restart recovery and multi-agent oversight become the main product value.

## Project List UX

- Default to only relevant projects: current set, saved presets, enabled rows, and last launch.
- Allow expanding to the full discovered project list on demand.
- Add a way to manually add folders outside the default `~/projects` root.
- Keep the main list biased toward projects that have actually been opened before, not every folder on disk.
- Treat "show all projects" as an intentional secondary action instead of the default state.

## Recovery Workflow

- Make restart recovery the primary path: open the app, inspect `Current Set` or `Last Launch`, save a preset if needed, and relaunch.
- Support restoring multiple tools across projects with clear per-project launch targets.

## Future Architecture

- Separate the current launcher UI from a future session-observer layer that inspects terminals, process trees, and agent status.
- Persist lightweight local metadata for presets, known project paths, default launch behavior, and session snapshots.
- Treat keep-alive, cache freshness, and agent-state reporting as a second product phase built on top of the launcher foundation.

## Near-Term Backlog

- Make live session detection resilient across iTerm layout changes, shell themes, and varying terminal footers.
- Add a simple "Add Folder" flow for projects outside `~/projects`.
- Make preset management feel first-class: rename, reorder, duplicate, and pin favorites.
- Decide whether multi-window-per-project should be modeled explicitly or remain a one-row-per-project simplification.
