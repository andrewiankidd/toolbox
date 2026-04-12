---
name: idleops
description: Drive any desktop GUI (launch apps, click buttons, type text, read on-screen text via OCR, take screenshots, wait for windows) using the user's local IdleOps toolkit at C:/git/idleops. Use this skill whenever the task needs to interact with a Windows UI you'd otherwise ask the user to operate manually — smoke-testing a build, navigating a launcher, verifying an installer, reaching a specific app state. Bridges the "LLMs can't click buttons" gap. Project-agnostic — the caller supplies the target window title and the click/key sequence.
---

IdleOps is the user's .NET automation toolkit at `C:\git\idleops`. It's a collection of standalone Windows CLIs that cover everything an LLM session normally can't do on a desktop: screenshotting, OCR, clicking, typing, waiting for UI states, recording/replaying workflows. Treat it as your hands and eyes for GUI tasks.

**Project-agnostic.** This skill documents capabilities and invocation patterns. The caller supplies project context: window title pattern, what text/keys to look for, what "success" means.

## When to reach for this skill

- User asks you to "test launching X," "verify the release build works," "walk through the menu and check Y"
- You need a running app to reach a specific state (trigger telemetry, reproduce a bug, unblock a follow-up step)
- You want a screenshot of the live app to visually confirm a change rather than asking the user
- A task needs a long-running UI process whose state you'd otherwise poll the user about

Skip this skill when the task is purely code/file-based.

## Read the examples before authoring

**IdleOps ships working playbook examples under `c:/git/idleops/src/playbk/inputs/`. Read one that resembles your task before writing your own.** They encode hard-won gotchas (WPF frameworks ignore PostMessage ALT+F4, WPF menu accelerators don't work remotely, OCR misreads small tab labels, etc.) that are tedious to rediscover.

| Example | What it demonstrates |
|---------|----------------------|
| [notepad-hello-world.idleops.yaml](c:/git/idleops/src/playbk/inputs/notepad-hello-world.idleops.yaml) | Minimal shape: launch → wait → type → close. Start here for simple flows. |
| [mspaint-smiley.idleops.yaml](c:/git/idleops/src/playbk/inputs/mspaint-smiley.idleops.yaml) | Mouse drag + draw coordination. |
| [smoke-test.idleops.yaml](c:/git/idleops/src/playbk/inputs/smoke-test.idleops.yaml) | Multi-tool sanity check. |
| [crosspose-gui-screenshots.idleops.yaml](c:/git/idleops/src/playbk/inputs/crosspose-gui-screenshots.idleops.yaml) | The gold standard — sidebar navigation, OCR clicks, pixel fallback when OCR fails, double-click via paired `inpctl` calls, graceful close of WPF windows via X-button coordinates, theme toggle through a native menu. Read this when your task is non-trivial. |
| [crosspose-doctor-screenshots.idleops.yaml](c:/git/idleops/src/playbk/inputs/crosspose-doctor-screenshots.idleops.yaml) | CLI-tool driving (not GUI) — `exec` with captured stdout, `%id_pid%` token use. |
| [crosspose-dekompose-screenshots.idleops.yaml](c:/git/idleops/src/playbk/inputs/crosspose-dekompose-screenshots.idleops.yaml) | Another real-world GUI automation — cross-reference when patterns feel unfamiliar. |

At skill call time: **glob the inputs directory, pick the closest match to the task, read it top-to-bottom, then adapt.** Don't hand-write a playbook from memory when a working one already demonstrates the pattern.

## playbk YAML is the preferred interface

The playbk script runner orchestrates everything else. Prefer authoring an `.idleops.yaml` playbook over hand-rolled bash — scripts are declarative, the error handling is built-in, process lifecycle is managed, and the action vocabulary is tiny.

### Action vocabulary (complete list)

```yaml
steps:
  # --- Launch a process (fire-and-forget) ---
  - id: myapp               # optional, enables %myapp_pid% in later steps
    name: Launch MyApp
    action: exec
    args: path/to/app.exe   # string or folded multi-line
    wait: false             # fire-and-forget; omit/true = wait for exit

  # --- Wait for a window to appear (optionally with OCR text) ---
  - name: Wait for main menu
    action: wait-window
    window: "MyApp*"        # wildcard title pattern
    text: "Start"           # optional — wait until this text OCR-matches
    timeout: 15             # seconds before failing

  # --- Click labeled text via OCR ---
  - name: Click Start button
    action: click-text
    window: "MyApp*"
    text: "Start"

  # --- Sleep (use sparingly; prefer wait-window) ---
  - name: Let data load
    action: sleep
    args: "2"               # string, whole-seconds or fractional

  # --- Capture a screenshot ---
  - name: Screenshot result
    action: screenshot
    window: "MyApp*"
    output: C:\path\to\out.png

  # --- Escape hatch: run any CLI, including inpctl directly ---
  - name: Send CTRL+S
    action: exec
    args: inpctl.exe --window "MyApp*" --keyboard "CTRL+S"
    wait: true
```

Only five verbs: `exec`, `wait-window`, `click-text`, `screenshot`, `sleep`. Everything else is achieved via `exec` into one of the underlying tools. The crosspose examples make heavy use of `exec` into `inpctl` for double-clicks, pixel-coordinate clicks, and window-close via title-bar X coordinates.

### Token expansion

If a step has `id: foo`, later steps can reference `%foo_pid%` in their `args` to get that process's PID. Useful for graceful-close via `inpctl --pid N --ctrlc` or for targeting a specific instance when multiple windows share a title.

### Running a playbook

```bash
# Debug playbk runs from the IdleOps tree with its bundled tools on PATH:
c:/git/idleops/src/playbk/bin/Debug/net10.0/playbk.exe \
    -i /path/to/your-playbook.idleops.yaml \
    -o /path/to/output/dir
```

The `-o` directory is where `screenshot` and `outcap` actions write their artifacts when paths are relative. Absolute `output:` paths (like the crosspose examples) bypass it.

## The underlying tools

Use these directly only when a one-off is simpler than writing a whole playbook. Canonical Debug paths:

| Tool | Path | One-line purpose |
|------|------|------------------|
| `scrcap` | `c:/git/idleops/src/playbk/bin/Debug/net10.0/scrcap.exe` | Screenshot a window to PNG |
| `txtfnd` | `c:/git/idleops/src/playbk/bin/Debug/net10.0/txtfnd.exe` | OCR a window, return `x,y` of a text match |
| `imgfnd` | `c:/git/idleops/src/imgfnd/bin/Debug/net10.0/imgfnd.exe` | Template-match a reference image in a window, return `x,y` |
| `inpctl` | `c:/git/idleops/src/playbk/bin/Debug/net10.0/inpctl.exe` | Send keyboard/mouse input to a window; resize/move/minimize/maximize |
| `waitfr` | `c:/git/idleops/src/waitfr/bin/Debug/net10.0-windows10.0.22621.0/waitfr.exe` | Poll until a window appears/disappears, optionally waiting for OCR text |
| `spkbak` | `c:/git/idleops/src/spkbak/bin/Debug/net10.0-windows10.0.22621.0/spkbak.exe` | Windows TTS — say text aloud or render to WAV |
| `audcap` | `c:/git/idleops/src/playbk/bin/Debug/net10.0/audcap.exe` | System audio capture (WASAPI loopback) |
| `vidcap` | `c:/git/idleops/src/playbk/bin/Debug/net10.0/vidcap.exe` | Screen/window video capture via ffmpeg |
| `outcap` | `c:/git/idleops/src/playbk/bin/Debug/net10.0/outcap.exe` | Parallel audio+video capture, auto-merge |
| `playbk` | `c:/git/idleops/src/playbk/bin/Debug/net10.0/playbk.exe` | YAML script runner — orchestrate the above |
| `stpcap` | `c:/git/idleops/src/stpcap/bin/Debug/net10.0/stpcap.exe` | Record keyboard/mouse into a playbk YAML (inverse of playbk) |
| `cnvrtr` | `c:/git/idleops/src/cnvrtr/bin/Debug/net10.0/cnvrtr.exe` | Cross-platform universal converter (encodings, hashes, units, media formats) |

If a Debug exe is missing, build it: `cd c:/git/idleops && dotnet build src/<tool>/<tool>.csproj`. Full docs at `c:/git/idleops/docs/README.md` and each tool's `docs/<tool>/README.md`. All tools support `--help`.

## What the caller must tell you

Before authoring a playbook, you need (or must ask for):

1. **Window title pattern** — `*`-wildcard glob that uniquely matches the target app. Always wildcards, never exact.
2. **Entry condition** — text visible when the app has finished loading, for the first `wait-window` guard.
3. **Navigation sequence** — ordered list of clicks/keystrokes to reach the goal state.
4. **Success condition** — text or window state that proves you arrived. Without this, automation is blind.
5. **Launch command** — how to start the app (plain path, `dotnet run`, `gh release download`, whatever).

If the caller hasn't supplied these, **ask before running anything.**

## Authoring a new playbook — the workflow

1. **Glob `c:/git/idleops/src/playbk/inputs/*.yaml`** and pick the closest match to the task.
2. **Read it** — note which `action:` verbs it uses, how it handles waits, how it closes the app.
3. **Copy to a working file** (e.g. `/tmp/$task.idleops.yaml`), adapt the window title, steps, and output paths.
4. **Run it** via the `playbk.exe` command above, capturing stdout/stderr.
5. **Verify** — inspect the screenshot output with the Read tool to confirm the UI actually reached the expected state.
6. **Report** back to the user with the screenshot attached and the playbook path.

If the playbook errors mid-run, don't retry blindly — the screenshot of the last-known state is your debug evidence. Look at it, adjust the coordinates/OCR text/timeouts, and rerun.

## Pitfalls & rules

- **Window titles change between platforms, locales, and builds.** Always wildcards. If OCR can't find a text you *know* is visible, first confirm the window matched at all — `screenshot` it and look.
- **Never click blind.** Require `txtfnd`/`imgfnd` to return non-empty before calling `inpctl --leftmouse`. The playbk `click-text` action handles this for you; if you reach for raw `exec` + `inpctl`, add the guard yourself.
- **OCR fails on small/stylized labels.** The crosspose-gui example hits this for tab headers and falls back to hardcoded pixel coordinates. When OCR fights you, do the same.
- **WPF windows ignore `PostMessage` ALT+F4.** The crosspose playbook closes windows by clicking the title-bar X button at known coordinates (`940,8` in its case). Apply the same pattern for WPF/WinUI apps.
- **Windows-only.** All tools except `cnvrtr` are Windows-only. If `uname -s` is not `MINGW*/MSYS*/CYGWIN*`, bail out and tell the user.
- **Process launch ≠ window ready.** Always `wait-window` between launching an app and the first interaction.
- **Graceful close matters.** Apps flush state on `WM_CLOSE` (ALT+F4, menu Quit, or clicking the X) but not on SIGKILL. For telemetry/save tests, close via the UI.
- **Don't use `--move-cursor` unless needed.** Default `inpctl` uses `PostMessage`/`SendInput` which doesn't steal focus; `--move-cursor` physically yanks the mouse. The crosspose playbook uses it only for menu items where WPF won't accept virtual input.
- **Don't use `stpcap` during a Claude session.** It installs a global keyboard hook — the user will see it. Only for explicit replay-script generation.
- **Never assume tools are on PATH.** When calling outside playbk, use absolute Debug paths. Inside a playbook, the tools are on PATH because playbk's build copies them next to `playbk.exe`.
- **Don't hardcode project knowledge into this skill.** If you discover project-specific details (an app's exact window title, a menu structure), put them in the *project's* CLAUDE.md or in the caller's prompt — not here.

## Combining with other skills

- `run-latest-release` → `idleops`: download + launch + drive in one pass. The playbook's first step `exec`s `bash .toolbox/.claude/skills/run-latest-release/run-latest-release.sh`.
- `idleops` → project verification (`debug-telemetry`, log check, file diff): reach a state, then prove it landed.
- `idleops` → attach a `screenshot` PNG when reporting "what did it look like after X."

IdleOps is the hands and eyes. Crosspose playbooks are the apprenticeship. The caller brings the destination.
