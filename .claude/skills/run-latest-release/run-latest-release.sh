#!/usr/bin/env bash
#
# run-latest-release.sh — download and run the latest GitHub release of the
# current (or a specified) repo. Project-agnostic; uses the gh CLI for auth
# & asset enumeration. Works for any kind of release binary, not just games.
#
# Usage:
#   run-latest-release.sh                   # auto-detect repo from cwd
#   run-latest-release.sh owner/repo        # explicit repo
#   run-latest-release.sh owner/repo <tag>  # specific release tag (defaults to latest)
#   RUN_LATEST_PATTERN=regex run-latest-release.sh   # override platform matcher
#
# Env vars:
#   RUN_LATEST_PATTERN  — regex (egrep) to match asset names. Overrides the
#                         default platform heuristic. Example:
#                           RUN_LATEST_PATTERN='Windows64.*\.zip'
#   RUN_LATEST_DIR      — scratch root. Defaults to /tmp/run-latest-release/.
#   RUN_LATEST_NO_RUN=1 — download + extract but don't launch.
#
# Exit codes: 0 ok, 1 usage/detection error, 2 no matching asset, 3 launch failed.

set -euo pipefail

REPO="${1:-}"
TAG="${2:-}"
SCRATCH_ROOT="${RUN_LATEST_DIR:-/tmp/run-latest-release}"

# ---------------------------------------------------------------------------
# 1. Resolve repo
# ---------------------------------------------------------------------------
if [ -z "$REPO" ]; then
    if ! command -v gh >/dev/null 2>&1; then
        echo "ERROR: gh CLI not found on PATH." >&2
        exit 1
    fi
    REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null || true)
fi
if [ -z "$REPO" ]; then
    echo "ERROR: No repo specified and not inside a GitHub repo." >&2
    echo "Usage: $0 [owner/repo] [tag]" >&2
    exit 1
fi
echo "Repo: $REPO"

# ---------------------------------------------------------------------------
# 2. Platform filter
# ---------------------------------------------------------------------------
OS_NAME="$(uname -s)"
case "$OS_NAME" in
    MINGW*|MSYS*|CYGWIN*) DEFAULT_RE='(windows|win64|win32|standalonewindows)' ;;
    Darwin)               DEFAULT_RE='(macos|osx|darwin|standaloneosx)' ;;
    Linux)                DEFAULT_RE='(linux|standalonelinux)' ;;
    *)                    DEFAULT_RE='.*' ;;
esac
PATTERN_RE="${RUN_LATEST_PATTERN:-$DEFAULT_RE}"
echo "Platform filter: /$PATTERN_RE/i"

# ---------------------------------------------------------------------------
# 3. Find matching asset
# ---------------------------------------------------------------------------
if [ -n "$TAG" ]; then
    ASSET_LIST=$(gh release view "$TAG" --repo "$REPO" --json assets --jq '.assets[].name')
else
    ASSET_LIST=$(gh release view --repo "$REPO" --json assets --jq '.assets[].name')
fi

if [ -z "$ASSET_LIST" ]; then
    echo "ERROR: No assets found on latest release of $REPO" >&2
    exit 2
fi

# Narrow by platform regex, prefer .zip then .tar.gz then raw.
ASSET=$(echo "$ASSET_LIST" | grep -iE "$PATTERN_RE" | grep -iE '\.zip$' | head -1 || true)
if [ -z "$ASSET" ]; then
    ASSET=$(echo "$ASSET_LIST" | grep -iE "$PATTERN_RE" | grep -iE '\.(tar\.gz|tgz)$' | head -1 || true)
fi
if [ -z "$ASSET" ]; then
    ASSET=$(echo "$ASSET_LIST" | grep -iE "$PATTERN_RE" | head -1 || true)
fi
if [ -z "$ASSET" ]; then
    echo "ERROR: No asset matching /$PATTERN_RE/ in $REPO release." >&2
    echo "Available assets:" >&2
    echo "$ASSET_LIST" | sed 's/^/  /' >&2
    echo "Hint: override with RUN_LATEST_PATTERN='yourRegex'" >&2
    exit 2
fi
echo "Asset: $ASSET"

# ---------------------------------------------------------------------------
# 4. Download & extract into a clean scratch dir
# ---------------------------------------------------------------------------
REPO_SAFE="${REPO//\//_}"
SCRATCH="$SCRATCH_ROOT/$REPO_SAFE"
mkdir -p "$SCRATCH"
rm -rf "$SCRATCH/extracted"
mkdir -p "$SCRATCH/extracted"

echo "Downloading to $SCRATCH..."
if [ -n "$TAG" ]; then
    gh release download "$TAG" --repo "$REPO" --pattern "$ASSET" --dir "$SCRATCH" --clobber
else
    gh release download --repo "$REPO" --pattern "$ASSET" --dir "$SCRATCH" --clobber
fi

DOWNLOAD="$SCRATCH/$ASSET"
EXTRACT="$SCRATCH/extracted"
echo "Extracting..."
case "$ASSET" in
    *.zip)          unzip -q -o "$DOWNLOAD" -d "$EXTRACT" ;;
    *.tar.gz|*.tgz) tar -xzf "$DOWNLOAD" -C "$EXTRACT" ;;
    *.tar)          tar -xf "$DOWNLOAD" -C "$EXTRACT" ;;
    *)              cp "$DOWNLOAD" "$EXTRACT/" ;;
esac

if [ "${RUN_LATEST_NO_RUN:-0}" = "1" ]; then
    echo "RUN_LATEST_NO_RUN=1 — extracted to $EXTRACT, not launching."
    exit 0
fi

# ---------------------------------------------------------------------------
# 5. Find executable & launch (platform-specific)
# ---------------------------------------------------------------------------
case "$OS_NAME" in
    MINGW*|MSYS*|CYGWIN*)
        EXE=$(find "$EXTRACT" -name '*.exe' -type f | head -1 || true)
        if [ -z "$EXE" ]; then
            echo "ERROR: No .exe found under $EXTRACT" >&2
            exit 3
        fi
        echo "Launching: $EXE"
        cmd.exe //c start "" "$(cygpath -w "$EXE")"
        ;;
    Darwin)
        APP=$(find "$EXTRACT" -name '*.app' -type d | head -1 || true)
        if [ -n "$APP" ]; then
            echo "Launching: $APP"
            open "$APP"
        else
            BIN=$(find "$EXTRACT" -type f -perm -u+x | head -1 || true)
            if [ -z "$BIN" ]; then
                echo "ERROR: No executable found under $EXTRACT" >&2
                exit 3
            fi
            echo "Launching: $BIN"
            "$BIN" &
        fi
        ;;
    Linux)
        BIN=$(find "$EXTRACT" -type f \( -name '*.x86_64' -o -name '*.AppImage' \) | head -1 || true)
        if [ -z "$BIN" ]; then
            BIN=$(find "$EXTRACT" -type f -executable ! -name '*.so*' | head -1 || true)
        fi
        if [ -z "$BIN" ]; then
            echo "ERROR: No executable found under $EXTRACT" >&2
            exit 3
        fi
        chmod +x "$BIN" 2>/dev/null || true
        echo "Launching: $BIN"
        "$BIN" &
        ;;
    *)
        echo "ERROR: Unsupported OS: $OS_NAME" >&2
        exit 3
        ;;
esac
