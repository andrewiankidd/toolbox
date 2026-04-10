---
name: changelog-public
description: Generate a casual, user-facing changelog from git history — written like dev blog updates, not technical release notes
---

Generate a casual changelog meant for players and followers, not developers. The tone should read like short dev blog updates or YouTube video descriptions.

## Style guide

**Do:**
- Write like you're telling a friend what you worked on
- Use plain language — "added doors" not "implemented cavity-based snap attachment for door structures"
- Keep bullets short — one line each, no sub-bullets
- Group by date (use the format "month day year" or "month day" — casual, not ISO)
- Collapse related work into single bullets — don't list every commit
- Use lowercase, no periods at end of bullets
- Skip commits that are pure chores (CI tweaks, linting, dependency bumps) unless they affect the player
- Mention fun/notable details if they exist ("broke some other stuff" is fine)

**Don't:**
- Use conventional commit prefixes (feat:, fix:, etc.)
- Use technical jargon (serialization, deserialization, singleton, autoload)
- Include commit hashes
- Use headers like "Added", "Fixed", "Changed"
- Be verbose — if a March update had 30 commits, it should still be ~5-10 bullets max
- Mention file paths or class names

**Example style:**
```
aug 5
- decoration tool previews the whole mesh now
- structure snapping now has 'internal snap' logic for ie doors, windows
- could have done this in five mins by updating the models but brute forced it with code instead

sep 6
- terrain generation
- configurable seed, size
- biomes with biome specific decor (trees, cacti)
```

## Step 1 — Determine range

- `git tag --sort=-v:refname | head -10` — recent tags
- `git log --oneline -20` — recent commits

If the user specified a range, use it. Otherwise default to all commits grouped by date.

## Step 2 — Gather commits

```
git log <range> --no-merges --format="%ad %s" --date=format:"%b %-d %Y"
```

Group commits by day. For days with many commits, read the actual diffs to understand what changed:
```
git diff <commit>~1..<commit> --stat
```

## Step 3 — Write it up

For each date (or cluster of dates if changes are small):
1. Write a date header (casual format: "march 22" or "aug 5")
2. Summarize the player-visible changes as short bullets
3. Collapse implementation details into plain descriptions
4. Skip anything the player wouldn't notice or care about

If there's a gap of weeks/months between activity, that's fine — just skip to the next date with changes.

## Step 4 — Output

Write the changelog as a plain markdown file. No YAML front-matter, no version numbers. Just dates and bullets.

## Step 5 — Write to file

Write the output to `CHANGELOG.PUBLIC.md` in the repository root.

## Rules

- Never fabricate changes — every bullet must trace back to real commits/diffs
- Read diffs when commit messages are unclear or too technical
- Aim for the tone of a solo dev posting updates, not a corporate release note
- If the user provides example entries for some dates, preserve those exactly and only generate entries for dates that aren't covered
