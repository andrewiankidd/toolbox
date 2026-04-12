---
name: run-latest-release
description: Download and launch the latest GitHub release of the current (or a specified) repo. Project-agnostic — uses the gh CLI to enumerate assets and pick a platform-appropriate binary. Use this when the user asks to run, test, or try the latest published release build of a project.
---

Download and run the latest release binary from a GitHub repository. Works for any project with GitHub releases — games, CLI tools, desktop apps, whatever. The real work happens in `run-latest-release.sh` alongside this file — your job is to pick the right arguments and run it.

## When to use this skill

- User asks to "run the latest build," "test the latest release," "try the published version," "play the latest build," etc.
- User wants to verify a shipped binary before pushing new changes
- User needs to reproduce a bug that only manifests in the published release

Skip this skill if the user wants to run from source (use the project's native run command instead, e.g. `godot --path src`, `cargo run`, `dotnet run`).

## How to invoke

Run the bundled script:

```bash
bash .toolbox/.claude/skills/run-latest-release/run-latest-release.sh
```

Arguments (all optional):

- `$1` — `owner/repo`. If omitted, the script uses `gh repo view` to auto-detect from the current working directory.
- `$2` — release tag. If omitted, uses the latest release.

Environment overrides:

- `RUN_LATEST_PATTERN='regex'` — override the platform asset matcher. The script defaults to an OS-appropriate regex (`windows|win64` on Windows, `macos|darwin` on macOS, `linux` on Linux). Override this when the project's asset names don't follow convention or when multiple platform-matching assets exist and you want a specific one. Example: `RUN_LATEST_PATTERN='Windows64.*\.zip'`.
- `RUN_LATEST_DIR=/path` — scratch directory. Defaults to `/tmp/run-latest-release/`. A per-repo subdirectory is created so multiple projects don't clobber each other.
- `RUN_LATEST_NO_RUN=1` — download and extract but do not launch. Useful when you only need to inspect the build.

The script prints every decision (repo, asset, platform filter, download target, launched binary) so you can relay progress to the user.

## What the script does

1. Resolves the target repo (arg → `gh repo view` → error).
2. Picks a platform regex from `uname -s` (Windows/macOS/Linux) unless `RUN_LATEST_PATTERN` overrides it.
3. Calls `gh release view` to list release assets, filters by the platform regex, and prefers `.zip` > `.tar.gz` > raw binaries.
4. Downloads the asset into `$RUN_LATEST_DIR/<owner>_<repo>/` via `gh release download --clobber`.
5. Extracts (zip/tar handled; raw binaries are copied as-is).
6. Finds an executable (`.exe` on Windows, `.app` or exec bit on macOS, `.x86_64` / `.AppImage` / exec bit on Linux) and launches it detached.

The script fails fast with a clear error if the repo can't be resolved (exit 1), no asset matches the filter (exit 2), or no runnable binary is found (exit 3). On asset-match failure it prints the full asset list so you can propose a `RUN_LATEST_PATTERN` override.

## Relaying output to the user

The launched binary runs detached — the script returns immediately after `start`/`open`/background exec. Tell the user "launched" but do not wait for the process; the window stays open until the user closes it.

If the script fails, quote its stderr verbatim and suggest the most likely fix:
- **Exit 1 (no repo):** ask the user for `owner/repo` or cd into a GitHub checkout.
- **Exit 2 (no asset):** show the available asset list from the error output and ask which pattern to use.
- **Exit 3 (no executable):** unusual — likely means the release ships source only, or the binary name is nonstandard. Ask the user what to do.

## Rules

- Do not modify the script during invocation — it's shared across projects. If it needs fixing, propose the edit and ask first.
- Do not run arbitrary downloaded binaries from repos the user has not explicitly named or checked out. This skill trusts the repo scope the user provides.
- Never use `sudo` or elevate — the script must run as the user's current shell.
