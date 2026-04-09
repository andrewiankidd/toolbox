---
name: changelog
description: Generate a changelog from git history between two refs (tags, commits, or branches)
---

Generate a human-readable changelog from git history.

## Step 1 — Determine range

- `git tag --sort=-v:refname | head -10` — recent tags
- `git log --oneline -20` — recent commits

If the user specified a range, use it. Otherwise default to the last tag to HEAD. If no tags exist, use the last 20 commits.

## Step 2 — Gather commits

```
git log <from>..<to> --oneline --no-merges
```

Read the full messages if subjects are ambiguous:
```
git log <from>..<to> --no-merges --format="%H %s"
```

## Step 3 — Categorize

Group commits by type using conventional commit prefixes:
- **Added** — `feat:`
- **Fixed** — `fix:`
- **Changed** — `refactor:`, `perf:`
- **Removed** — commits that remove features or deprecations
- **Other** — `chore:`, `docs:`, `test:`, `ci:` (include only if notable)

If commits don't follow conventional commits, categorize by reading the diff.

## Step 4 — Format

Output as markdown:

```markdown
## [version or range] — YYYY-MM-DD

### Added
- Description of feature (commit hash)

### Fixed
- Description of fix (commit hash)

### Changed
- Description of change (commit hash)
```

Omit empty sections. Keep descriptions concise — rewrite commit messages for clarity if needed, don't just copy them verbatim.

## Rules

- Never fabricate commits or changes
- If a commit is unclear, read the diff to understand what it actually does
- Collapse related commits into a single entry where it makes sense
