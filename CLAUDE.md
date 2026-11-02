# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

"Офіс жуків" (Ukrainian for "Bug Office"): a Godot 4.7 project (GL Compatibility renderer, GDScript only) that draws each running Claude Code session as a pixel bug working at a desk or resting in a lounge. It is a visualization fed by a separate monitor process, not a game with its own state. Scripts use tab indentation and static typing.

**Language.** Player-facing strings are in Ukrainian: bug speech lines (`CAUGHT_LINES`, `CLOSED_LINES`, `PET_LINES`, `POIS` in `agent.gd`; `LINES` and `PET_LINES` in `officer.gd`; `PET_LINES` in `minion.gd`), status text in `sidebar.gd` (`STATUS_TEXT`), the window title and the monitor-missing alert in `main.gd`. Write new player-facing text in Ukrainian. Code comments and identifiers are in English.

## Commands

There is no test suite, linter, or CI config. Verification is done by running the app.

- Run the app (starts the monitor if needed, then Godot): `./run.sh`
- Run with fake sessions instead of the monitor: `./run.sh -- --demo`
- Re-import the project (needed after adding or renaming a `class_name` script, since `.godot/` caches the global class list and is gitignored):
  `steam-run "$HOME/Data/SteamLibrary/steamapps/common/Godot Engine/godot.x11.opt.tools.64" --headless --path . --import`

`run.sh` hardcodes the Godot binary path under `$HOME/Data/SteamLibrary` and wraps it in `steam-run`; on another machine these need editing.

**Checking a visual change.** Use `--demo` and watch the scene. `DemoSource` runs a fixed script of about 70 seconds per agent (busy → shell → blocked → busy → idle), so every status and the team animation show up within a minute. Two guest sessions appear and close at 6–22 s and 36–52 s, which triggers the TCK van and the officers. Demo data is the only way to see those paths without a live session.

## Architecture

**Data flow.** `main.gd` polls `http://127.0.0.1:8765/api/sessions` every 2 seconds. The response is `{sessions: [...], now: <unix time>}`. The endpoint is served by an external Python process, `~/Documents/projects/claude-monitor/monitor.py`, which `run.sh` launches if the port is not answering. With `--demo`, `DemoSource` produces the same session dictionaries instead. Everything downstream consumes only those dictionaries.

**Session lifecycle.** `Main._apply` maps each session id to an `Agent` (a pixel bug) and syncs its `subagents` into `Minion` followers keyed `"<session>:<subagent id>"`. A session that disappears from the poll is marked `ended`: its agent walks to the door, the TCK `Van` is summoned, and three `Officer` bugs (`OFFICER_COUNT`) chase, catch, and drag it into the van. The van leaves only when all ended agents are loaded and every officer is hidden. Caught agents are removed through `_on_loaded` → `_remove`.

**Agent state machine** (`agent.gd`). States are WALKING, WORKING, RESTING, FLEEING, ESCORTED, OUTSIDE. A session with status `idle` for at least `REST_AFTER_IDLE` seconds sets `wants_rest`, which moves the bug to the lounge; a busy session moves it back to a desk. Movement is path-based, and the routes come from `Layout`. Resting bugs cycle through acts (`SLEEP`, `SIP`, `WANDER` to a point of interest, `LOOK`, `DANCE`) in `_next_act`.

**Seats and overflow.** `Main.slots` is one array covering all seats: the 8 desks first, then the lounge seats. `Layout.DESK_COUNT` is hardcoded to 8 and must equal `COLS.size() * ROWS.size()`. `is_lounge(i)` relies on the index ordering, so desks must stay before lounge seats. Bugs that find no free seat wait outside in `_waiting` and are retried every frame.

**Rendering.** The world is drawn in a `SubViewport` at 1/4 scale (`Layout.PIXEL = 4`) with nearest filtering, so all sprites land on one pixel grid. Game code uses 1600x900 scene coordinates. Text labels and speech bubbles live on a separate `CanvasLayer` (`overlay`) so they stay sharp. The right 340 px is the `Sidebar` (roster, stats, details of the selected session).

**Drawing bugs** (`bug_body.gd`, `gfx.gd`). Sprites are character grids, one character per 4 px cell, drawn by `Gfx.sprite(ci, pos, rows, palette)`. `Gfx` also has ellipse and rounded-rectangle polygon helpers, since `_draw` has no such primitives. `BugBody` is shared by agents, subagents and officers. Its `kind` (from `BugBody.kind_of(model)`: OPUS, SONNET, HAIKU, FABLE, OTHER) selects the color and body size from `LOOKS`. Other visible traits: `crowned` (leads a team), `uniform` (TCK camouflage), `mini` (subagent, drawn by `_draw_mini`), `hat` (subagent cap), `alert` (blinking mark when blocked). The `pose` enum selects the animation. The body never rotates; `look` moves the eyes and `walk()` advances the leg stride. `_process` snaps the body to the pixel grid so it doesn't jitter against the parent's movement.

**Input.** `Main._unhandled_input` handles petting: a click or drag over a bug calls `pet()`, which spawns hearts and speech lines. Clicking an agent also selects it in the sidebar. `PET_RADIUS` sets how close the cursor must be.

## Tuning

Most behavior is controlled by constants at the top of a few files, so change them there rather than hunting through logic:

- `main.gd`: `POLL_SECONDS`, `REST_AFTER_IDLE`, `DEPART_DELAY`, `OFFICER_COUNT`, `PET_RADIUS`.
- `layout.gd`: world geometry (`OFFICE_W`, `COLS`, `ROWS`, `LOUNGE_SEATS`, `MAX_TEAM`) and the walking lanes. Changing the seat count also changes `DESK_COUNT`.
- `agent.gd`: walk, flee and stroll speeds, and the points of interest in `POIS`.
- `sidebar.gd`: `X` and `W` set the sidebar's position and width. Keep `X` equal to `Layout.OFFICE_W`.

## Project settings

`project.godot` matters for rendering: the window is 1600x900 with stretch mode `canvas_items` and `keep` aspect, the GUI uses the `fonts/unscii-16.otf` pixel font, and the renderer is GL Compatibility. The default clear color is a near-black. A pixel look depends on these, so changing them changes how the whole scene looks.

## Gotchas

- Everything is built in code. `main.tscn` is only a root `Node2D` with `main.gd` attached.
- Each `.gd` file has a sibling `.gd.uid` file. Keep them with their scripts.
- The monitor's JSON contract is not documented in this repo. The fields read are `sessionId`, `name`, `title`, `status`, `statusSince`, `model`, `commands`, `feed`, `subagents`, and `now`. Check `scripts/agent.gd` and `scripts/main.gd` before changing any of them.
