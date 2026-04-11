# Vision

Ideas that should shape the product beyond the current launcher workflow.

## Session Management

- Detect the real live session set from open terminal windows instead of relying only on saved UI state.
- Treat `Current Set` as a continuously updated snapshot of open agent windows and their associated projects.
- Keep `Last Launch` as a separate snapshot that records exactly what the app launched most recently.
- Allow saving the live `Current Set` directly as a named preset.
- Distinguish between total live agent windows and the subset that can be mapped cleanly back to project folders.
- Persist lightweight local "seen before" metadata so frequently used projects remain visible without exposing them in the public repo.
- Prefer explicit apply over continuous overwrite:
  - live detection should drive status and summaries
  - toggles should update via explicit actions (`Load Current Set`, `Load Preset`, `Load Last Launch`) instead of constant auto-mutation
- Add periodic local auto-snapshots (target: every 10–15 minutes) so unexpected restarts still have a recent recoverable set.
- Snapshot on app lifecycle events (background/quit) when possible to improve recovery quality.

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
- Include "recently opened but currently off" rows in the default list when they are likely to be useful for quick relaunch.
- Keep auxiliary variants (for example `*-coordination`, `*-worktrees`) hidden by default unless active/referenced, or shown when `Show All` is enabled.

## State Provenance UX

- Clearly indicate what currently drives the UI selection:
  - live detected set
  - loaded preset name
  - last launch snapshot
  - manual edits since load
- Show `Last Live Refresh` timestamp and a human-readable age (for example `refreshed 3m ago`).
- If auto-snapshot is enabled, show `Last Auto Snapshot` timestamp so restart confidence is obvious.

## Recovery Workflow

- Make restart recovery the primary path: open the app, inspect `Current Set` or `Last Launch`, save a preset if needed, and relaunch.
- Support restoring multiple tools across projects with clear per-project launch targets.
- After unexpected shutdown, prioritize recovery from the most recent valid auto-snapshot, then allow one-click promotion to a named preset.

## Future Architecture

- Separate the current launcher UI from a future session-observer layer that inspects terminals, process trees, and agent status.
- Persist lightweight local metadata for presets, known project paths, default launch behavior, and session snapshots.
- Treat keep-alive, cache freshness, and agent-state reporting as a second product phase built on top of the launcher foundation.

## Near-Term Backlog

- Make live session detection resilient across iTerm layout changes, shell themes, and varying terminal footers.
- Add a simple "Add Folder" flow for projects outside `~/projects`.
- Make preset management feel first-class: rename, reorder, duplicate, and pin favorites.
- Decide whether multi-window-per-project should be modeled explicitly or remain a one-row-per-project simplification.
- Implement snapshot scheduler and provenance labels before adding further detection heuristics.
