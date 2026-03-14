---
name: ship
description: Prepare a project for GitHub publication — generate README, .gitignore,
  LICENSE, clean artifacts, init git, and produce a pre-push checklist.
  Designed for projects that passed /review-project with KEEP recommendation.
version: 3.5.0
context: fork
agent: general-purpose
allowed-tools: Read, Grep, Glob, Bash, Write, Edit
argument-hint: <project-path> [--license MIT|Apache-2.0|GPL-3.0] [--org ramic-dev] [--private]
---

You are running the **ship** skill. Prepare a project directory for GitHub publication. Generate all missing scaffolding, clean up artifacts, and produce a checklist of what's ready and what needs manual attention.

All generated content (README, comments, commit messages) must be in **English**.

Work through all phases autonomously. Never ask clarifying questions.

**Context pressure:** this skill reads only identity files and entry points — not the whole codebase. If the project is large, focus on structure and config, not every source file.

**Portability:** all bash commands must work on Linux, macOS, AND Windows (Git Bash). Use `|| true` on commands that may exit non-zero. Use `find -print0 | xargs -0` instead of `xargs -d '\n'`.

---

## Phase 1 — Parse Arguments & Analyze Project

Parse `$ARGUMENTS`:
- First token: `PROJECT_PATH` — the project to ship. Required.
- `--license <type>`: license type. Default: `MIT`. Options: `MIT`, `Apache-2.0`, `GPL-3.0`.
- `--org <name>`: GitHub org/user. Default: read from `git config user.name` or `git remote`, fallback `ramic-dev`.
- `--private`: create as private repo. Default: public.

```bash
cd "<PROJECT_PATH>" && pwd   # → ROOT
basename "<ROOT>"            # → PROJECT_NAME
git config user.name 2>/dev/null || echo "ramic-dev"
command -v gh >/dev/null 2>&1 && echo "gh: available" || echo "gh: not found"
```

### Structural pre-check

Before analyzing content, check for structural issues that affect WHERE files should be generated:

```bash
# Multi-version directories?
ls -d "<ROOT>"/v[0-9]* "<ROOT>"/[0-9][0-9][0-9][0-9]-* "<ROOT>"/backup* "<ROOT>"/old* 2>/dev/null || true

# Single-child wrapper? (root has only one subdirectory and nothing else)
contents=$(ls "<ROOT>" | wc -l)
[ "$contents" -eq 1 ] && echo "WRAPPER: root contains single subdirectory — consider flattening"
```

If multi-version: **warn in the report** that the user should consolidate to one version before shipping. Suggest which version to keep (largest/newest). Generate files targeting the recommended version's directory, not the outer root.

If single-child wrapper: **warn in the report** that the nesting should be flattened before shipping. Generate files at the inner directory level, not the wrapper.

### Analyze the project

Read identity files to understand the project. Search broadly — don't assume files are at root:

```bash
# Find all identity files (maxdepth 3, skip noise)
find "<ROOT>" -maxdepth 3 \( \
  -iname "README*" -o -iname "ARCHITECTURE*" -o -iname "CLAUDE*" \
  -o -name "package.json" -o -name "composer.json" -o -name "Cargo.toml" \
  -o -name "requirements.txt" -o -name "pyproject.toml" -o -name "Pipfile" \
  -o -name "build.gradle" -o -name "build.gradle.kts" -o -name "settings.gradle*" \
  -o -name "manifest.json" -o -name "project.godot" \
  -o -name "*.info.yml" \
  -o -name "gradle.properties" -o -name "fabric.mod.json" -o -name "neoforge.mods.toml" \
  -o -name "Gemfile" -o -name "go.mod" -o -name "Package.swift" \
  -o -name "docker-compose.yml" -o -name "docker-compose.yaml" \
  -o -name "tsconfig.json" \
  -o -name "Makefile" -o -name "Dockerfile" \
  -o -name ".env.example" \
\) ! -path "*/.git/*" ! -path "*/node_modules/*" ! -path "*/vendor/*" \
  ! -path "*/.godot/*" ! -path "*/.gradle/*" \
  2>/dev/null || true
```

Read the found files. Determine:
- **What it does** (1-2 sentences, from code — not aspirational)
- **Project type** — one of: Game / Web app / CLI tool / Library-framework / API / Browser extension / CMS module / Minecraft mod / Other
- **Tech stack** (primary language, framework, runtime, key dependencies)
- **How to install** (dependency install command — or "no install needed")
- **How to run** — varies by type:
  - Static HTML: any HTTP server (`python3 -m http.server`)
  - Node.js: `npm start` or from package.json scripts
  - Godot: "Open in Godot X.x editor, run Main.tscn"
  - Chrome extension: "Load as unpacked extension in chrome://extensions (developer mode)"
  - Gradle: `./gradlew build` or `./gradlew runClient` for Minecraft mods
  - Python: `python main.py` or from scripts
  - Ruby: `bundle exec puma`, `rackup`, `bundle exec rails server`
  - Go: `go run .` or `go build -o <name> && ./<name>`
  - Swift: `swift run` (CLI) or "Open in Xcode, Cmd+R" (app)
  - Docker: if Dockerfile/docker-compose exists, mention `docker compose up` as alternative
- **How to build** (if applicable)

---

## Phase 2 — Generate README.md

If `README.md` exists at root (or in the target version directory) and is substantial (> 20 lines of real content), **read it and improve** — fill gaps, fix inaccuracies, don't replace wholesale.

If missing or stub, generate from scratch. Choose the template that fits the **project type**:

### Template: Game
```markdown
# PROJECT_NAME

[What the game is and what makes it interesting — 1-2 sentences.]

## Play

[How to run — open index.html via HTTP server, npm start, open in Godot, etc.]

## Features

- [Implemented feature 1]
- [Implemented feature 2]

## Tech Stack

- [Language, engine/framework, notable libraries]

## License

[License type]
```

### Template: CLI tool / Library / Framework
```markdown
# PROJECT_NAME

[What it does and why — 1-2 sentences.]

## Install

```bash
[install command]
```

## Usage

```bash
[usage examples — from actual code, not imagined]
```

## License

[License type]
```

### Template: Web app / API
```markdown
# PROJECT_NAME

[What it does — 1-2 sentences.]

## Quick Start

```bash
[install + run commands]
```

## Features

- [Feature 1]
- [Feature 2]

## Configuration

[Environment variables, config files, or "No configuration needed."]

## Tech Stack

- [Language, framework, database, etc.]

## License

[License type]
```

### Template: Browser extension
```markdown
# PROJECT_NAME

[What it does — 1-2 sentences.]

## Install

1. Clone this repository
2. Open `chrome://extensions` in Chrome (or `about:addons` in Firefox)
3. Enable "Developer mode"
4. Click "Load unpacked" and select the project folder

## Features

- [Feature 1]
- [Feature 2]

## Permissions

- `[permission]` — [why it's needed]

## Requirements

- [Browser version, hardware requirements, etc.]

## Tech Stack

- [Language, APIs used]

## License

[License type]
```

### Template: CMS module (Drupal / WordPress plugin)
```markdown
# PROJECT_NAME

[What the module does and which CMS it extends — 1-2 sentences.]

## Requirements

- [CMS name and minimum version, e.g., Drupal 10.2+]
- [PHP version, e.g., PHP 8.1+]
- [Any required contrib modules or libraries]

## Install

1. Copy/clone this module to `[modules/custom/|wp-content/plugins/]PROJECT_NAME`
2. `[drush en PROJECT_NAME|wp plugin activate PROJECT_NAME]` or enable via admin UI

## Configuration

[Where to find settings — e.g., `/admin/config/...` — or "No configuration needed."]

## Features

- [Feature 1]
- [Feature 2]

## Tech Stack

- [CMS, PHP version, any JS framework used in admin UI]

## License

[License type]
```

### Template: Minecraft mod
```markdown
# PROJECT_NAME

[What the mod does — 1-2 sentences.]

## Requirements

- Minecraft [version from gradle.properties / fabric.mod.json]
- [Mod loader(s): Fabric / Forge / NeoForge — list all supported]
- [Required dependencies, e.g., Fabric API, Architectury API]

## Install

1. Install [mod loader] for Minecraft [version]
2. Download the latest release `.jar` from [Releases page / CurseForge / Modrinth]
3. Place the `.jar` in your `mods/` folder

## Features

- [Feature 1]
- [Feature 2]

## Building from Source

```bash
./gradlew build
# Output JARs in [fabric/build/libs/ | build/libs/]
```

## Tech Stack

- Java [version], [Fabric API / Forge MDK / NeoForge / Architectury]
- Minecraft [version]

## License

[License type]
```

### Template: Monorepo
```markdown
# PROJECT_NAME

[What the project does — 1-2 sentences.]

## Packages

| Package | Description |
|---------|-------------|
| `packages/api` | [description] |
| `packages/web` | [description] |
| `packages/shared` | [description] |

## Quick Start

```bash
npm install        # installs all workspaces
npm run dev        # starts all packages
```

## Tech Stack

- [list per-package tech]

## License

[License type]
```

### Template: Mobile app / Widget
```markdown
# PROJECT_NAME

[What the app does — 1-2 sentences.]

## Requirements

- [iOS version / Android version]
- [Xcode version / Android Studio version]

## Build

```bash
[build from source commands]
```

## Features

- [Feature 1]
- [Feature 2]

## License

[License type]
```

### Rules for all README types:
- No badges, no emojis unless the project already uses them
- Features section lists **actually implemented** features (verify in code) — never aspirational
- Run/install commands must **actually work** — inferred from package.json/Makefile/manifest.json/project.godot
- If the project requires env vars, API keys, or external services, add a **Configuration** section
- If there are multiple entry points or modes, document each
- Keep it concise — prefer 30 lines over 100
- Omit sections that don't apply (e.g., no "Controls" for a framework, no "Permissions" for a game)
- **Monorepo detection:** If the project has a `workspaces` field in root `package.json` (npm/yarn monorepo), use the Monorepo template instead of Web app/API. List each workspace package with its purpose.
- **Architectury/multi-loader mods:** If the project has `common/` + `fabric/` + `forge/` + `neoforge/` directories, mention multi-loader support in the README. Extract the Minecraft version from `gradle.properties` (`minecraft_version`) or `fabric.mod.json` and note which loaders are supported (Fabric, Forge, NeoForge).
- **Multi-step setup:** If the project requires more than 2 commands to get running (e.g., create virtualenv, install deps, configure `.env`, run migrations, seed database, start server), use a numbered list in Quick Start instead of a single code block:
  ```markdown
  ## Quick Start

  1. Clone and install dependencies:
     ```bash
     git clone https://github.com/ORG/PROJECT_NAME.git && cd PROJECT_NAME
     [install command]
     ```
  2. Configure environment:
     ```bash
     cp .env.example .env
     # Edit .env — set DATABASE_URL, API_KEY, etc.
     ```
  3. Set up the database:
     ```bash
     [migration command, e.g., python manage.py migrate]
     ```
  4. Run the application:
     ```bash
     [start command]
     ```
  ```
  Detect multi-step setup by checking for: `.env.example`, migration files (`alembic/`, `migrations/`, `prisma/`), `docker-compose.yml`, `Makefile` with setup target, or setup scripts (`setup.sh`, `init.sh`).

---

## Phase 3 — Generate .gitignore

If `.gitignore` exists, **read it and extend** with any missing patterns for the detected stack.

If missing, generate based on the detected tech stack:

```gitignore
# OS
.DS_Store
Thumbs.db
desktop.ini

# IDE
.vscode/
.idea/
*.swp
*.swo
*~
.vs/
```

**Add per-stack patterns — only for technologies actually present in the project:**

| Stack | Patterns to add |
|-------|----------------|
| Node.js | `node_modules/`, `dist/`, `build/`, `.env`, `.env.local`, `*.log`, `coverage/`, `.next/`, `.nuxt/` |
| PHP | `vendor/`, `.env`, `*.log`, `.phpunit.result.cache` |
| Drupal | `sites/default/files/`, `sites/default/settings.local.php`, `*.ht.sqlite`, `sites/*/private/`, `sites/simpletest/` |
| Python | `__pycache__/`, `*.pyc`, `.venv/`, `venv/`, `*.egg-info/`, `.env`, `*.egg` |
| Rust | `target/` (keep `Cargo.lock` for binaries, gitignore for libraries) |
| Godot | `.godot/`, `*.import`, `*.uid`, `export_presets.cfg`, `export/` |
| .NET/C# | `bin/`, `obj/`, `*.user`, `*.suo` |
| Java/Gradle | `build/`, `.gradle/`, `out/`, `*.class` |
| Architectury / multi-loader | `*/build/`, `.architectury-transformer/` |
| Chrome extension | `*.pem`, `*.crx`, `*.zip`, `web-ext-artifacts/` |
| Ruby | `*.gem`, `.bundle/`, `vendor/bundle/`, `.env`, `tmp/`, `log/`, `coverage/`, `.byebug_history` |
| Go | binary name (project name without extension), `vendor/` (if go mod vendor), `*.test`, `*.out` |
| Swift/Xcode | `.build/`, `.swiftpm/`, `DerivedData/`, `*.xcodeproj/xcuserdata/`, `*.xcworkspace/xcuserdata/`, `xcuserdata/`, `*.moved-aside`, `Packages/`, `Package.resolved` (for libraries) |
| General | `*.log`, `*.tmp`, `*.bak`, `*.old` |

Never add patterns for technologies not detected in the project.

**Mixed-purpose directories:** When a directory contains BOTH source/docs files AND runtime/generated files (e.g., `.swarm/` with docs + `swarm.db` + `swarm.log`), do NOT gitignore the whole directory. Instead, add per-file patterns:
```gitignore
# .swarm/ — keep docs, ignore runtime
.swarm/*.db
.swarm/*.log
.swarm/*.pid
```
This preserves committable files (`.md`, `.py`, `.yml`, `.json`, `.sql`) while excluding runtime artifacts (`.db`, `.sqlite`, `.log`, `.pid`, `.sock`).

**IMPORTANT:** After Phase 5 (cleanup scan), revisit this file and add any patterns needed to cover the cleanup findings (databases, runtime files, etc.). Phase 3 generates the initial .gitignore; Phase 5 may extend it.

---

## Phase 4 — Generate LICENSE

If `LICENSE`, `LICENSE.md`, or `COPYING` exists at root or in the target directory, **skip**.

If missing, generate the specified license:
- Year: from `git log --reverse --format=%ai 2>/dev/null | head -1`, or current year if no git history
- Author: from `--org`, or `git config user.name`, or `package.json` author

**MIT license — full text:**
```
MIT License

Copyright (c) YEAR AUTHOR

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

---

## Phase 5 — Identify Cleanup

Scan for files that should not be committed. **List them for user review — never delete automatically.**

```bash
# Artifacts and temp files
find "<ROOT>" -type f \( \
  -name "*.log" -o -name "*.tmp" -o -name "*.bak" -o -name "*~" \
  -o -name ".DS_Store" -o -name "Thumbs.db" -o -name "desktop.ini" \
  -o -name "*.pyc" -o -name "*.pyo" -o -name "*.class" \
  -o -name "tmpclaude-*" \
\) ! -path "*/.git/*" ! -path "*/.godot/*" ! -path "*/.gradle/*" \
  -print0 2>/dev/null | xargs -0 -r ls -la 2>/dev/null || true

# Dead code / superseded files
find "<ROOT>" -type f \( \
  -name "*_old.*" -o -name "*_backup.*" -o -name "*_deprecated.*" -o -name "*_bak.*" \
  -o -name "old_*" \
  -o -name "*.old" -o -name "*.orig" \
  -o -name "*_v[0-9].*" \
\) ! -path "*/.git/*" 2>/dev/null || true

# Large files (> 500KB)
find "<ROOT>" -type f ! -path "*/.git/*" ! -path "*/node_modules/*" \
  ! -path "*/vendor/*" ! -path "*/target/*" ! -path "*/.godot/*" ! -path "*/.gradle/*" \
  -print0 2>/dev/null | xargs -0 -r wc -c 2>/dev/null | sort -rn | awk '$1 > 512000 {print}' | head -10

# Sensitive files — CRITICAL CHECK
find "<ROOT>" -type f \( \
  -name ".env" -o -name "*.pem" -o -name "*.key" -o -name "*.p12" \
  -o -name "credentials*" -o -name "secrets*" -o -name "*password*" \
  -o -name "*.sqlite" -o -name "*.sqlite3" -o -name "*.db" -o -name "*.ht.sqlite" \
  -o -name "id_rsa*" -o -name "*.pfx" \
\) ! -path "*/.git/*" 2>/dev/null || true

# Empty source files (scaffolded stubs never implemented)
find "<ROOT>" -type f \( -name "*.js" -o -name "*.ts" -o -name "*.py" -o -name "*.php" \
  -o -name "*.rs" -o -name "*.gd" -o -name "*.java" \
  -o -name "*.go" -o -name "*.rb" -o -name "*.swift" \) -empty \
  ! -path "*/.git/*" ! -path "*/node_modules/*" 2>/dev/null || true
```

**Filter out already-gitignored files** (if git repo exists):
```bash
# For each found file, check if .gitignore already covers it
git -C "<ROOT>" check-ignore <found-file> 2>/dev/null
```
Don't flag files that are already gitignored.

Classify each found item:
- **DELETE** — temp files, OS artifacts, dead code (`*_old.*`, empty stubs)
- **GITIGNORE** — runtime files (databases, logs, build output). **Immediately use the Edit tool to append these patterns to `.gitignore`** (the file generated in Phase 3). Do not defer this — add each discovered pattern to `.gitignore` before finishing Phase 5.
- **REVIEW** — large files (might be intentional assets), sensitive files (might be examples)
- **KEEP** — intentional project files

**Mixed-purpose directories:** When a directory contains both source/docs AND runtime files, classify each file individually:
- `.swarm/schema.md` → **KEEP**
- `.swarm/OPERATIONS.md` → **KEEP**
- `.swarm/swarm.db` → **GITIGNORE** (per-file pattern, not whole dir)
- `.swarm/swarm.log` → **GITIGNORE** (per-file pattern)

Use action label `GITIGNORE (per-file — dir has docs)` in the cleanup table to explain why it's not a blanket directory ignore. Add the per-file patterns to `.gitignore` (e.g., `.swarm/*.db`, `.swarm/*.log`) instead of ignoring the whole directory.

---

## Phase 6 — Config Validation

Validate the project's package metadata based on detected tech stack. Only check/fix what applies.

### Node.js (`package.json`)
Flag missing fields:
- `name` — should match repo name, lowercase
- `description` — should match README first line
- `version` — semver (default `1.0.0`)
- `license` — should match LICENSE file
- `scripts.start` — how to run. **Skip for browser games** that need a static server, not npm.
- `main` or `module` — entry point. **Only for libraries/packages**, not games or apps.
- `private: true` — add if NOT meant for npm registry

### Chrome extension (`manifest.json`)
Flag issues:
- `version` — should be semver-ish (Chrome prefers `X.Y.Z`, not `X.Y`)
- `description` — should be in English if targeting international audience
- Missing `author` field
- Missing `homepage_url` (optional but good for GitHub)

### Python (`pyproject.toml` / `requirements.txt`)
If NEITHER exists but Python files use imports that require `pip install`:
- **Create `requirements.txt`** using this method:
  1. Collect all `import` and `from ... import` statements:
     ```bash
     find "<ROOT>" -name "*.py" ! -path "*/.git/*" ! -path "*/.venv/*" ! -path "*/venv/*" \
       -print0 2>/dev/null | xargs -0 -r grep -h '^\(import\|from\) ' 2>/dev/null \
       | sed 's/^from \([^ .]*\).*/\1/' | sed 's/^import \([^ ,]*\).*/\1/' \
       | sort -u
     ```
  2. Filter out stdlib modules (use Python's `sys.stdlib_module_names` or a known list: `os`, `sys`, `re`, `json`, `pathlib`, `typing`, `collections`, `datetime`, `math`, `random`, `hashlib`, `logging`, `argparse`, `unittest`, `io`, `time`, `functools`, `itertools`, `subprocess`, `shutil`, `glob`, `copy`, `string`, `textwrap`, `threading`, `socket`, `http`, `urllib`, `xml`, `csv`, `sqlite3`, `email`, `base64`, `uuid`, `dataclasses`, `enum`, `abc`, `contextlib`, `traceback`, `inspect`, `pprint`, `struct`, `ctypes`, `signal`, `multiprocessing`, `concurrent`, `asyncio`, `warnings`)
  3. Also scan shell scripts and READMEs for `pip install` commands:
     ```bash
     grep -rh 'pip install' "<ROOT>" --include="*.sh" --include="*.md" --include="*.txt" \
       2>/dev/null | sed 's/.*pip install //' | tr ' ' '\n' | grep -v '^-' | sort -u
     ```
  4. Map top-level import names to PyPI package names where they differ (common mappings: `PIL`→`Pillow`, `cv2`→`opencv-python`, `bs4`→`beautifulsoup4`, `sklearn`→`scikit-learn`, `yaml`→`PyYAML`, `dotenv`→`python-dotenv`, `gi`→`PyGObject`, `attr`→`attrs`)
  5. Write one package per line, no version pins (user can pin later)
- Flag the absence in the checklist

### Rust (`Cargo.toml`)
Flag missing: `description`, `license`, `repository`

### Godot (`project.godot`)
Flag issues:
- `config/name` should match repo name
- `config/description` should exist
- `run/main_scene` should be set

### Gradle (`build.gradle` / `build.gradle.kts`)
Flag missing: `group`, `version`, `description` in build config

### Architectury (`gradle.properties`)
For Architectury/multi-loader projects, check `gradle.properties` for:
- `minecraft_version` — targeted Minecraft version
- `mod_version` — current mod version (should be semver)
- `archives_base_name` — artifact name
- `supported_loaders` — which platforms are built (may be implicit from directory structure)

### Ruby (`Gemfile`)
Flag missing `ruby` version constraint. Suggest creating a `.ruby-version` file if one does not exist.

### Go (`go.mod`)
Flag issues:
- `module` path should match intended GitHub URL (e.g., `github.com/ORG/PROJECT_NAME`)
- Go version should be reasonable (not excessively old or newer than latest stable)
- Verify `go.sum` exists — flag if missing

### Swift (`Package.swift`)
Flag issues:
- Missing `platforms` declaration (e.g., `.macOS(.v12)`, `.iOS(.v15)`)
- Check `swift-tools-version` comment at top of file — should be present and reasonable
- Verify product names match project conventions

Fix any missing fields directly (use Edit tool). For Python, create `requirements.txt` if missing.

---

## Phase 7 — Git Setup

```bash
if git -C "<ROOT>" rev-parse --is-inside-work-tree 2>/dev/null; then
  echo "GIT: exists"
  git -C "<ROOT>" remote -v 2>/dev/null || echo "REMOTE: none"
  git -C "<ROOT>" status --short 2>/dev/null | wc -l  # count uncommitted files
  git -C "<ROOT>" log --oneline -5 2>/dev/null
else
  echo "GIT: not initialized"
  # Do NOT init here — suggest in checklist
fi

command -v gh >/dev/null 2>&1 && echo "gh: available" || echo "gh: not found"
```

**Do NOT create commits, push, or init git.** Suggest all commands in the checklist.

---

## Phase 8 — Report & Checklist

```
/ship — PROJECT_NAME
══════════════════════════════════════════════════════════

[If structural issues found:]
## ⚠ Structural Issues
- [Multi-version: v1, v2, v3 found — consolidate to vN before shipping]
- [Wrapper directory: root has single subdirectory — flatten before shipping]
- [Redundant nesting: path/to/same-name/ — remove one level]

## Generated Files
- [created/updated/skipped] README.md
- [created/updated/skipped] .gitignore [+ patterns added from cleanup findings]
- [created/skipped] LICENSE
- [created/skipped/n/a] requirements.txt (Python only, if was missing)

## Config Metadata
- [fixed/ok/n/a] [package.json / manifest.json / Cargo.toml / project.godot / ...]
- [details of what was fixed]

## Cleanup Needed
| File | Size | Action | Reason |
|------|------|--------|--------|
| .env | 234B | GITIGNORE | contains credentials |
| Kernel_old.gd | 57KB | DELETE | superseded by Kernel.gd |
| build/ | 12MB | GITIGNORE | build output |
If nothing found: "No cleanup needed."

## Sensitive Files Check
[List any .env, .pem, .key, .sqlite, credentials files found]
[If none: "No sensitive files detected."]

## Git Status
- Repository: [not initialized / exists (N commits)]
- Remote: [none / origin → URL]
- Uncommitted files: [N]

## Pre-Push Checklist
- [ ] [If structural issues:] Flatten/consolidate directory structure first
- [ ] Review generated README.md for accuracy
- [ ] Handle each cleanup item listed above
- [ ] Ensure .gitignore covers all GITIGNORE items before committing
- [ ] Verify no sensitive data will be committed
- [ ] Run the project once to confirm it works
- [ ] [If not git repo:] git init && git checkout -b main
- [ ] git add -A && git commit -m "Initial commit — [project description]"
- [ ] [If no remote:] gh repo create ORG/PROJECT_NAME --public --source=. --push
- [ ] [If remote exists:] git push -u origin main

## Suggested Repo
ORG/PROJECT_NAME ([public/private])
```
