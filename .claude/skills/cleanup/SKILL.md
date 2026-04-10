---
name: cleanup
description: Find dead code, unused imports, stale TODOs, and other cruft in the codebase
---

Scan the codebase for cruft and report findings. Do not auto-fix unless the user asks.

## What to look for

### Dead code
- Unused functions/methods — defined but never called anywhere
- Unused variables and parameters
- Unreachable code after returns/throws
- Commented-out code blocks (not explanatory comments — actual dead code in comments)

### Unused imports/dependencies
- Imports that nothing in the file references
- NuGet/npm/pip packages in project files that no source file uses

### Stale TODOs
- `TODO`, `FIXME`, `HACK`, `XXX` comments — list them with file and line
- Flag any that reference closed issues, removed features, or dates in the past

### Empty/stub implementations
- Empty catch blocks
- Methods that just `throw new NotImplementedException()`
- Interfaces with no implementations

### Config/build cruft
- Duplicate entries in project files
- Unused build configurations
- Orphaned config files for tools no longer in use

## Process

1. Identify the project type and language(s) from the repo structure
2. Focus the search on source directories — skip `bin/`, `obj/`, `node_modules/`, `.git/`, vendor dirs
3. For each category, search systematically using grep/glob
4. Report findings grouped by category with file paths and line numbers
5. Prioritize: dead code and unused dependencies first, stale TODOs last

## Output format

List findings grouped by category. For each item:
- File path and line number
- What it is and why it's flagged
- Suggested action (remove, investigate, update)

## Rules

- Don't flag test mocks or intentionally unused parameters (prefixed with `_`)
- Don't flag code that's used via reflection, DI registration, or framework conventions
- When in doubt, flag as "investigate" rather than "remove"
- Do not make changes unless explicitly asked
