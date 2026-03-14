---
name: review-project
description: Analyze a project directory and produce a structured evaluation report
  with completeness estimate, tech stack, vault coverage, and recommendation
  (KEEP/ARCHIVE/NEEDS-TESTING). Designed for rapid triage when reviewing
  many projects to decide which to complete and publish vs. discard.
version: 5.4.0
context: fork
agent: general-purpose
allowed-tools: Read, Grep, Glob, Bash, Write, Edit
argument-hint: <project-path> [vault-path]
---

You are running the **review-project** skill. Analyze a project directory and produce a structured evaluation to help the user decide: complete it and push to GitHub, or archive it.

Work through all phases autonomously. Never ask clarifying questions.

**Context pressure:** if the project has > 200 source files, focus on entry points, README, config files, and the 10 largest custom source files. Do not attempt to read everything — that's `/distill`'s job.

**Portability:** all bash commands must work on Linux, macOS, AND Windows (Git Bash). Use `|| true` on any command that may exit non-zero when nothing matches (ls globs, find, gh). Use `find -print0 | xargs -0` instead of `xargs -d '\n'` (macOS xargs doesn't support `-d`).

---

## Phase 1 — Parse Arguments

- First token: `PROJECT_PATH` — the project to review. Required.
- Second token (optional): `VAULT_PATH` — knowledge vault location. Default: `D:/knowledge`

```bash
cd "<PROJECT_PATH>" && pwd   # → ROOT
basename "<ROOT>"            # → PROJECT_NAME
```

---

## Phase 2 — Project Structure Scan

**Noise directories to exclude from ALL find commands:**
`.git/`, `node_modules/`, `__pycache__/`, `vendor/`, `dist/`, `build/`, `.vs/`, `.next/`, `target/`, `.godot/`, `.gradle/`, `.venv/`, `venv/`, `.claude/`

```bash
# Top-level structure
ls -la "<ROOT>"

# Full file tree (excluding noise)
find "<ROOT>" -type f \
  ! -path "*/.git/*" ! -path "*/node_modules/*" ! -path "*/__pycache__/*" \
  ! -path "*/vendor/*" ! -path "*/dist/*" ! -path "*/build/*" \
  ! -path "*/.vs/*" ! -path "*/.next/*" ! -path "*/target/*" \
  ! -path "*/.godot/*" ! -path "*/.gradle/*" ! -path "*/.venv/*" ! -path "*/venv/*" \
  ! -path "*/.claude/*" \
  2>/dev/null | head -200

# Count by extension (filter out extensionless files)
find "<ROOT>" -type f -name "*.*" \
  ! -path "*/.git/*" ! -path "*/node_modules/*" ! -path "*/vendor/*" \
  ! -path "*/target/*" ! -path "*/.godot/*" ! -path "*/.gradle/*" \
  2>/dev/null | sed 's/.*\.//' | sort | uniq -c | sort -rn | head -20

# Total file count
find "<ROOT>" -type f \
  ! -path "*/.git/*" ! -path "*/node_modules/*" ! -path "*/vendor/*" \
  ! -path "*/.godot/*" ! -path "*/.gradle/*" \
  2>/dev/null | wc -l
```

**Count custom code lines.** The extension list covers common languages — add more if the project uses an unlisted one:
```bash
find "<ROOT>" -type f \( \
  -name "*.js" -o -name "*.ts" -o -name "*.jsx" -o -name "*.tsx" \
  -o -name "*.php" -o -name "*.module" -o -name "*.twig" \
  -o -name "*.py" \
  -o -name "*.rs" -o -name "*.go" \
  -o -name "*.gd" -o -name "*.gdshader" \
  -o -name "*.java" -o -name "*.kt" -o -name "*.scala" -o -name "*.swift" \
  -o -name "*.cpp" -o -name "*.c" -o -name "*.h" \
  -o -name "*.rb" -o -name "*.lua" \
  -o -name "*.sh" -o -name "*.bash" -o -name "*.ps1" -o -name "*.bat" -o -name "*.cmd" \
  -o -name "*.sql" \
  -o -name "*.html" -o -name "*.css" -o -name "*.scss" \
\) \
  ! -path "*/.git/*" ! -path "*/node_modules/*" ! -path "*/vendor/*" \
  ! -path "*/dist/*" ! -path "*/build/*" ! -path "*/target/*" \
  ! -path "*/.godot/*" ! -path "*/.gradle/*" ! -path "*/__pycache__/*" \
  ! -path "*/.venv/*" ! -path "*/venv/*" \
  ! -path "*/web/core/*" ! -path "*/docroot/core/*" \
  ! -path "*/modules/contrib/*" ! -path "*/themes/contrib/*" \
  ! -name "*.min.js" ! -name "*.min.css" \
  ! -name "*_old.*" ! -name "*_backup.*" \
  -print0 2>/dev/null | xargs -0 wc -l 2>/dev/null | tail -1
```

### Architectury / multi-loader mod detection

```bash
# Architectury / multi-loader mod structure
if [ -d "<ROOT>/common/src" ] && { [ -d "<ROOT>/fabric/src" ] || [ -d "<ROOT>/forge/src" ] || [ -d "<ROOT>/neoforge/src" ]; }; then
  echo "ARCHITECTURY: multi-loader mod detected (common + platform modules)"
  # Count real code (common/) vs platform wrappers
  common_lines=$(find "<ROOT>/common" \( -name "*.java" -o -name "*.kt" \) -print0 2>/dev/null | xargs -0 wc -l 2>/dev/null | tail -1 | awk '{print $1}')
  platform_lines=$(find "<ROOT>/fabric" "<ROOT>/forge" "<ROOT>/neoforge" \( -name "*.java" -o -name "*.kt" \) -print0 2>/dev/null | xargs -0 wc -l 2>/dev/null | tail -1 | awk '{print $1}')
  echo "  Common (shared code): ${common_lines:-0} lines"
  echo "  Platform wrappers: ${platform_lines:-0} lines"
fi
```

### Multi-version detection

```bash
# Detect version/snapshot directories — || true prevents exit code 2
ls -d "<ROOT>"/v[0-9]* "<ROOT>"/*-v[0-9]* \
      "<ROOT>"/backup* "<ROOT>"/old* "<ROOT>"/current* \
      "<ROOT>"/[0-9][0-9][0-9][0-9]-* \
      2>/dev/null || true
# If results include files (not directories), ignore them — version detection is for directories only.
```

If multiple versions/snapshots are found:
1. **Count code lines per version:**
   ```bash
   for vdir in "<ROOT>"/*/; do
     [ -d "$vdir" ] || continue
     name=$(basename "$vdir")
     lines=$(find "$vdir" -type f \( -name "*.js" -o -name "*.ts" -o -name "*.php" -o -name "*.py" \
       -o -name "*.rs" -o -name "*.gd" -o -name "*.java" -o -name "*.html" -o -name "*.css" \
       -o -name "*.ps1" -o -name "*.sh" -o -name "*.sql" -o -name "*.module" \) \
       ! -name "*.min.js" ! -name "*.min.css" \
       -print0 2>/dev/null | xargs -0 wc -l 2>/dev/null | tail -1 | awk '{print $1}')
     files=$(find "$vdir" -type f ! -path "*/.git/*" 2>/dev/null | wc -l)
     echo "$name: ${lines:-0} lines, $files files"
   done
   ```
2. **Recommend which version to ship** (typically the largest/newest)
3. **Report total lines = latest version only** — don't inflate by summing all versions
4. **Check for redundant nesting** — directories like `v2-2026-02-09/2026-02-09/`

### Multi-project / monorepo detection

```bash
# Detect independent subprojects: subdirectories with their own identity files
identity_dirs=$(find "<ROOT>" -mindepth 2 -maxdepth 3 \( \
  -name "package.json" -o -name "composer.json" -o -name "Cargo.toml" \
  -o -name "pyproject.toml" -o -name "build.gradle" -o -name "build.gradle.kts" \
  -o -name "project.godot" -o -name "go.mod" \
  -o -name "Gemfile" -o -name "Package.swift" \
\) ! -path "*/node_modules/*" ! -path "*/vendor/*" ! -path "*/.git/*" \
  2>/dev/null || true)

if [ -n "$identity_dirs" ]; then
  echo "SUBPROJECT IDENTITY FILES:"
  echo "$identity_dirs"
  # Check if subprojects use different tech stacks (= multi-project, not monorepo)
  echo "TECH STACKS PER SUBPROJECT:"
  echo "$identity_dirs" | while read -r f; do
    dir=$(dirname "$f")
    base=$(basename "$f")
    echo "  $(basename "$dir")/ — $base"
  done
fi
```

If multiple identity files exist at **different directory levels** with the **same type** (e.g., multiple `package.json`), flag as **monorepo**:
```bash
# Check if root has workspaces/workspace field (npm/yarn monorepo)
grep -q '"workspaces"\|"workspace"' "<ROOT>/package.json" 2>/dev/null && echo "MONOREPO: npm/yarn workspaces detected"
```
```
- **Structure:** Monorepo — N workspaces detected (package.json at root + N subdirs)
```

If subdirectories have **different identity file types** (e.g., one has `package.json`, another has `Cargo.toml`), flag as **multi-project directory** — not a single project:
```
- **Structure:** Multi-project directory — N independent subprojects (different tech stacks)
```
In this case, recommend reviewing each subproject separately with `/review-project <subdir>`.

### Wrapper directory detection

```bash
# Detect wrapper: all meaningful code in a single subdirectory
top_dirs=$(find "<ROOT>" -mindepth 1 -maxdepth 1 -type d \
  ! -name ".git" ! -name "node_modules" ! -name "__pycache__" \
  ! -name ".vs" ! -name ".venv" ! -name "venv" ! -name ".claude" \
  ! -name ".github" ! -name ".vscode" ! -name ".idea" \
  2>/dev/null || true)
top_dir_count=$(echo "$top_dirs" | grep -c . 2>/dev/null || echo 0)
top_files=$(find "<ROOT>" -maxdepth 1 -type f ! -name ".*" 2>/dev/null | wc -l)

if [ "$top_dir_count" -eq 1 ] && [ "$top_files" -le 2 ]; then
  sole_dir=$(echo "$top_dirs" | head -1)
  sole_name=$(basename "$sole_dir")
  inner_files=$(find "$sole_dir" -type f ! -path "*/.git/*" 2>/dev/null | wc -l)
  echo "WRAPPER: all code appears to be in $sole_name/ ($inner_files files) — consider re-rooting"
fi
```

If detected, add to Cleanup flags:
```
- Wrapper directory — all code is in `<subdir>/`. Consider making `<subdir>/` the project root.
```

### CMS module detection

```bash
# Detect Drupal module/theme (not a standalone project)
info_ymls=$(find "<ROOT>" -maxdepth 3 -name "*.info.yml" ! -path "*/contrib/*" ! -path "*/core/*" 2>/dev/null || true)
if [ -n "$info_ymls" ]; then
  has_core=$(find "<ROOT>" -maxdepth 2 \( -name "core.services.yml" -o -name "drupal.php" \) 2>/dev/null | head -1)
  has_composer_drupal=$(grep -l "drupal/core" "<ROOT>/composer.json" 2>/dev/null || true)
  if [ -z "$has_core" ] && [ -z "$has_composer_drupal" ]; then
    echo "CMS MODULE: *.info.yml found without Drupal core — this is a module/theme, not a standalone app"
    echo "$info_ymls"
  fi
fi
```

If detected, report in Identity:
```
- **Type:** CMS module (Drupal module/theme — not a standalone application)
```

### Anomalous file/directory detection

```bash
# Redundant nesting: subdirectory with same name as parent
for d in "<ROOT>"/*/; do
  [ -d "$d" ] || continue
  child="$d$(basename "$d")"
  [ -d "$child" ] && echo "NESTING: $child"
done || true

# Superseded files: _old, _backup, _deprecated, _bak, old_*, .old suffix, _v2/_v3 variants
find "<ROOT>" -type f \( \
  -name "*_old.*" -o -name "*_backup.*" -o -name "*_deprecated.*" -o -name "*_bak.*" \
  -o -name "old_*" \
  -o -name "*.old" \
  -o -name "*_v[0-9].*" \
\) ! -path "*/.git/*" 2>/dev/null || true

# Database files (important to flag — shouldn't be committed without LFS)
find "<ROOT>" -type f \( -name "*.sqlite" -o -name "*.sqlite3" -o -name "*.db" -o -name "*.ht.sqlite" \) \
  ! -path "*/.git/*" 2>/dev/null || true

# Empty source files (0 bytes — likely placeholders or accidental)
find "<ROOT>" -type f -empty \( \
  -name "*.js" -o -name "*.ts" -o -name "*.py" -o -name "*.php" -o -name "*.rs" \
  -o -name "*.java" -o -name "*.kt" -o -name "*.gd" -o -name "*.sh" \
  -o -name "*.go" -o -name "*.rb" -o -name "*.swift" \
\) ! -path "*/.git/*" ! -path "*/node_modules/*" ! -path "*/vendor/*" \
  2>/dev/null || true
```

### Mixed-purpose directory detection

```bash
# Mixed-purpose directories: dirs containing both source/docs AND runtime/generated files
for d in "<ROOT>"/*/; do
  [ -d "$d" ] || continue
  has_source=$(find "$d" -maxdepth 1 -type f \( -name "*.md" -o -name "*.py" -o -name "*.js" -o -name "*.php" -o -name "*.yml" -o -name "*.json" \) 2>/dev/null | head -1)
  has_runtime=$(find "$d" -maxdepth 1 -type f \( -name "*.db" -o -name "*.sqlite" -o -name "*.log" -o -name "*.pid" -o -name "*.sock" \) 2>/dev/null | head -1)
  [ -n "$has_source" ] && [ -n "$has_runtime" ] && echo "MIXED: $(basename "$d")/ — contains both source and runtime files"
done || true
```

Flag any findings in the `## Cleanup flags` section. For mixed-purpose directories, flag individually:
```
- `.swarm/` — mixed-purpose directory: contains docs (commit) + runtime files (gitignore individually)
```

---

## Phase 3 — Identity & Tech Stack

**Vault shortcut — read FIRST, before any source file:**
```bash
cat "<VAULT_PATH>/_index/<PROJECT_NAME>.md" 2>/dev/null
```
If the `## Note` section exists and is substantial, use it as the primary project description. Only read source files to verify or fill gaps.

**Search for README in all locations** (note whether at root or buried):
```bash
find "<ROOT>" -maxdepth 3 -iname "README*" ! -path "*/.git/*" ! -path "*/.godot/*" 2>/dev/null || true
```

**Identity files** (read fully if < 100 lines, first 50 otherwise):
- `README*`, `ARCHITECTURE*`, `DESIGN*`, `CLAUDE*`, `STATE*`, `AGENTS*`, `PLANS*`
- `package.json`, `composer.json`, `Cargo.toml`, `requirements.txt`, `pyproject.toml`, `Pipfile`
- `Gemfile` (Ruby), `go.mod` (Go), `Package.swift` (Swift/SPM)
- `build.gradle`, `build.gradle.kts`, `settings.gradle`, `settings.gradle.kts`, `gradle.properties`
- `manifest.json` (Chrome/Firefox extensions — primary identity file)
- `fabric.mod.json`, `mods.toml`, `neoforge.mods.toml` (Minecraft mods — primary identity)
- `Makefile`, `Dockerfile`, `docker-compose*`
- `.env.example`, `config.*`
- `project.godot` (check `run/main_scene` for entry point), `*.csproj`, `*.sln`
- Drupal: `*.info.yml` (module/theme identity)

If the identity file is NOT at the project root, search deeper:
```bash
find "<ROOT>" -maxdepth 3 \( -name "package.json" -o -name "composer.json" -o -name "Cargo.toml" \
  -o -name "build.gradle" -o -name "build.gradle.kts" -o -name "project.godot" \
  -o -name "manifest.json" -o -name "*.info.yml" \
  -o -name "Gemfile" -o -name "go.mod" -o -name "Package.swift" \) \
  ! -path "*/node_modules/*" ! -path "*/vendor/*" ! -path "*/.godot/*" \
  2>/dev/null || true
```

**Entry points** (read first 80 lines):
- `index.html`, `index.php`, `index.js`, `main.*`, `app.*`, `server.*`
- `src/main.*`, `src/index.*`, `src/app.*`, `src/lib.*`
- Godot: scene from `project.godot` `run/main_scene`
- Chrome extensions: `background.js`, `popup.html`, `content.js` (from `manifest.json`)
- Java: class with `public static void main` or `@SpringBootApplication`
- Gradle: `./gradlew tasks` or read `build.gradle` for `application { mainClass }`

**For web projects and games**, also extract the `<title>` tag:
```bash
grep -rh "<title>" "<ROOT>" --include="*.html" 2>/dev/null | head -3
```

**Git status:**
```bash
if git -C "<ROOT>" rev-parse --is-inside-work-tree 2>/dev/null; then
  echo "GIT: yes"
  git -C "<ROOT>" remote -v 2>/dev/null || echo "GIT REMOTE: none"
  git -C "<ROOT>" log --oneline -15 --format="%h %ad %s" --date=short 2>/dev/null
  gh repo view "$(git -C "<ROOT>" remote get-url origin 2>/dev/null)" --json name,url 2>/dev/null || true
else
  echo "GIT: not a git repository"
fi
```

Report git status as one of:
- `not a git repository`
- `git repo, no remote`
- `git repo, remote: <URL>`
- `git repo, remote: <URL>, already on GitHub`

**Scaffolding checks:**
```bash
# LICENSE
find "<ROOT>" -maxdepth 2 \( -iname "LICENSE*" -o -iname "COPYING*" \) 2>/dev/null || true

# .gitignore
find "<ROOT>" -maxdepth 2 -name ".gitignore" 2>/dev/null || true

# CI/CD
find "<ROOT>" -maxdepth 3 -path "*/.github/workflows/*" -name "*.yml" 2>/dev/null || true
ls "<ROOT>"/.gitlab-ci.yml 2>/dev/null || true

# Lock files — search deep, cover all ecosystems
find "<ROOT>" -maxdepth 3 \( \
  -name "package-lock.json" -o -name "yarn.lock" -o -name "pnpm-lock.yaml" \
  -o -name "composer.lock" -o -name "Cargo.lock" -o -name "Gemfile.lock" \
  -o -name "poetry.lock" -o -name "Pipfile.lock" -o -name "uv.lock" \
  -o -name "gradle.lockfile" \
  -o -name "go.sum" -o -name "Package.resolved" \
\) ! -path "*/.git/*" ! -path "*/node_modules/*" 2>/dev/null || true
```

If NO lock files found, report `no lock files` and distinguish:
- No dependency manager present → `(no external dependencies)`
- Has package.json/composer.json/Cargo.toml but no lock → `(dependencies not installed)`
- Godot/engine with no package manager → `(n/a — engine project)`
- Gradle without lockfile → `(Gradle — lock file optional)`

If a lock file is found but is empty (0 bytes), note it as `(found but empty — dependencies not installed)`.
- Go — `go.sum`
- SPM — `Package.resolved` typically gitignored for libraries

**Asset size check** (images, audio, video, fonts, binaries, databases, 3D models):
```bash
find "<ROOT>" -type f \( \
  -name "*.png" -o -name "*.jpg" -o -name "*.jpeg" -o -name "*.gif" -o -name "*.webp" \
  -o -name "*.svg" -o -name "*.ico" -o -name "*.psd" \
  -o -name "*.mp3" -o -name "*.ogg" -o -name "*.wav" -o -name "*.flac" \
  -o -name "*.mp4" -o -name "*.webm" \
  -o -name "*.ttf" -o -name "*.otf" -o -name "*.woff" -o -name "*.woff2" \
  -o -name "*.zip" -o -name "*.7z" -o -name "*.tar" -o -name "*.gz" \
  -o -name "*.dmg" -o -name "*.exe" -o -name "*.app" -o -name "*.apk" -o -name "*.pck" -o -name "*.msi" \
  -o -name "*.wasm" \
  -o -name "*.glb" -o -name "*.gltf" -o -name "*.blend" -o -name "*.fbx" -o -name "*.obj" \
  -o -name "*.sqlite" -o -name "*.sqlite3" -o -name "*.db" \
\) ! -path "*/.git/*" ! -path "*/node_modules/*" ! -path "*/.godot/*" ! -path "*/.gradle/*" \
  -print0 2>/dev/null | xargs -0 wc -c 2>/dev/null | tail -1
```
If no files found, report `none`. If total > 10MB (10000000 bytes), flag: `⚠ large assets — consider Git LFS or .gitignore`.

From all of the above, determine:

| Field | What to extract |
|-------|----------------|
| **What it does** | 1-2 sentence description (from vault `## Note` first, then README, then code) |
| **Project type** | Game / Web app / CLI tool / Library / API / Browser extension / CMS site / Minecraft mod / Other |
| **Tech stack** | Languages, frameworks, key dependencies |
| **Run command** | How to start it. Varies by type: web server for HTML, `npm start`, `./gradlew runClient`, open in Godot, load as unpacked extension, etc. |
| **Dependencies** | External services needed. "None (self-contained)" if standalone. For runtime-fetched deps (CDN imports, model downloads), note separately. |
| **Origin** | Original / fork of X / clone of Y. Check: git remotes, README attribution, license copyright, manifest metadata (fabric.mod.json sources/contact), Java package names matching known GitHub orgs. |
| **Git status** | One of the four states above |

---

## Phase 4 — Completeness Assessment

| Dimension | How to check |
|-----------|-------------|
| **Code volume** | Lines from Phase 2 (latest version only, excluding `*_old*`). <50 = trivial, 50-500 = small, 500-2000 = medium, 2000-10000 = substantial, >10000 = large. **Architectury/multi-loader:** base volume on `common/` lines only — platform wrappers (`fabric/`, `forge/`, `neoforge/`) inflate the count 3-4x with near-identical adapters. |
| **Functionality** | Grep for incomplete markers. NOTE: do NOT include `pass$` (standard Python/GDScript). For Rust, also search `todo!()` and `unimplemented!()`. `grep -rn "TODO\|FIXME\|HACK\|NotImplemented\|raise NotImplementedError\|todo!()\|unimplemented!()" "<ROOT>" --include="*.js" --include="*.ts" --include="*.php" --include="*.module" --include="*.py" --include="*.rs" --include="*.gd" --include="*.java" --include="*.kt" --include="*.rb" --include="*.go" --include="*.swift" --include="*.ps1" --include="*.sh" --include="*.bat" --include="*.sql" --exclude-dir=".git" --exclude-dir="node_modules" --exclude-dir="vendor" --exclude-dir="target" --exclude-dir=".godot" --exclude-dir=".gradle" --exclude-dir="__pycache__" 2>/dev/null \| wc -l` |
| **Tests** | Count test files — restrict to CODE extensions to avoid false positives (e.g., `spectre.svg`): `find "<ROOT>" -type f \( -name "*test*.js" -o -name "*test*.ts" -o -name "*test*.py" -o -name "*test*.php" -o -name "*test*.rs" -o -name "*test*.java" -o -name "*test*.gd" -o -name "*spec*.js" -o -name "*spec*.ts" -o -name "*spec*.py" \
  -o -name "*test*.rb" -o -name "*spec*.rb" \
  -o -name "*_test.go" -o -name "*test*.go" \
  -o -name "*test*.swift" -o -name "*Test*.swift" \) ! -path "*/.git/*" ! -path "*/node_modules/*" ! -path "*/.godot/*" 2>/dev/null \| wc -l`. For Rust: also count inline test modules: `grep -rl "#\[cfg(test)\]" "<ROOT>" --include="*.rs" 2>/dev/null \| wc -l` |
| **Documentation** | **Root README** exists and has > 20 lines? Or README only in subdirectory (note location)? ARCHITECTURE/DESIGN docs? |
| **Config** | Working config? Only `.example` files? Missing entirely? |
| **Lock file** | See Phase 3 |
| **CI/CD** | Workflow files present? |
| **Git** | Not a repo / N commits / last commit date |
| **LICENSE** | Present at root (or in subdirectory)? |
| **.gitignore** | Present? |
| **Runnable** | Could it run as-is? |

Assign a **completeness level:**

| Level | Criteria |
|-------|----------|
| **Skeleton** | < 100 lines. File structure, minimal implementation. |
| **Prototype** | 100-1000 lines. Core feature works, rough edges. |
| **MVP** | 1000-5000 lines. One complete workflow end-to-end. |
| **Mature** | 5000+ lines or multiple features. Some tests, docs, config. |
| **Polished** | Mature + tests + docs + CI + clean code. Release-ready. |

Guidelines — a 200-line CLI tool can be Polished; a 10000-line mess can be Prototype. Use judgment, state the evidence.

---

## Phase 5 — Vault Coverage Check

```bash
# Read full index (with ## Note section)
cat "<VAULT_PATH>/_index/<PROJECT_NAME>.md" 2>/dev/null

# Find all vault notes from this project (exact match in YAML list)
grep -rl "[[ ,]<PROJECT_NAME>[],]" "<VAULT_PATH>/notes/" 2>/dev/null

# Show titles and scores
for f in $(grep -rl "[[ ,]<PROJECT_NAME>[],]" "<VAULT_PATH>/notes/" 2>/dev/null); do
  score=$(grep -m1 "^score:" "$f" | awk '{print $2}')
  title=$(grep -m1 "^title:" "$f" | sed 's/^title: "//;s/"$//')
  echo "  $score | $title"
done | sort -rn
```

If distilled: report concepts count, avg score, top notes (score ≥ 7), status, and `## Note` verbatim.
If NOT distilled: note as gap, recommend `/distill` before deciding.

---

## Phase 6 — Recommendation

### KEEP — Complete and publish to GitHub
**When:** original code, clear purpose, at least Prototype, NOT already on GitHub.
Include: what's missing, multi-version guidance, effort estimate (Small/Medium/Large), suggested repo name.

### ARCHIVE — Preserve knowledge, discard code
**When:** vault coverage adequate, OR skeleton, OR fork without modifications, OR superseded.
Include: what to run first (`/preserve`, `/distill`), list captured concepts.

### NEEDS-TESTING — Run it first, then decide
**When:** completeness unclear without running it.
Include: exact run command, what to test, key decision question.

---

## Output Format

```
/review-project — PROJECT_NAME
══════════════════════════════════════════════════════════

## Identity
- **What:** [1-2 sentence description]
- **Type:** [Game / Web app / CLI tool / Library / API / Extension / CMS site / Minecraft mod]
- **Stack:** [languages, frameworks]
- **Origin:** [original / fork of X]
- **Run:** `[command]` [or "load as unpacked extension" / "open in Godot 4.x" / "./gradlew runClient"]
- **Deps:** [none (self-contained) / npm (N packages) / requires API key / runtime CDN imports / ...]
- **Git:** [not a git repository / git repo, no remote / git repo, remote: URL]

## Structure
- **Files:** N source files (N total)
- **Custom code:** ~N lines [if multi-version: "(vX only — latest)"]
- **Extensions:** .js (N), .php (N), ...
- **Lock file:** [yes (npm/cargo/gradle) / no (no deps) / no (not installed) / n/a (engine)]
- **Tests:** [N test files / N inline test modules (Rust) / none]
- **CI/CD:** [yes (.github/workflows) / none]
- **Assets:** [N MB / none] [if >10MB: "⚠ Git LFS"]
- **LICENSE:** [yes (MIT/Apache/...) / missing]
- **.gitignore:** [yes / missing]

[If multi-version:]
## Versions
| Version | Lines | Files | Notes |
|---------|-------|-------|-------|
| v1 | N | N | [diff] |
| v3 | N | N | [latest, recommended] |

[If multi-project directory:]
## Multi-Project Directory
This directory contains N independent subprojects with different tech stacks.
Review each separately: `/review-project <subdir>`
| Subproject | Stack | Identity File |
|------------|-------|---------------|
| frontend/ | Node.js | package.json |
| backend/ | Rust | Cargo.toml |

[If monorepo:]
## Monorepo
- **Workspaces:** N packages detected
- **Root identity:** package.json / Cargo.toml
- **Packages:** list...

[If wrapper directory detected:]
## Wrapper Directory
All code is in `<subdir>/` (N files). The outer directory adds no value.
Consider re-rooting to `<subdir>/` before publishing.

[If CMS module (not standalone):]
## CMS Module
This is a Drupal module/theme, not a standalone application.
It requires a host Drupal installation to run.

[If Architectury/multi-loader:]
## Multi-Loader Structure
- **Common (shared):** ~N lines — the real code
- **Fabric:** ~N lines (platform wrapper)
- **Forge:** ~N lines (platform wrapper)
- **NeoForge:** ~N lines (platform wrapper)
Code volume assessment based on common/ only.

[If cleanup needed:]
## Cleanup flags
- `path/to/issue` — description
- ...

## Completeness: [LEVEL]
| Dimension | Status |
|-----------|--------|
| Code volume | [N lines — size] |
| Functionality | [N TODOs / clean] |
| Tests | [N files / none] |
| Documentation | [root README / subdir only / missing] |
| Config | [working / missing / not needed] |
| Git | [N commits, last: YYYY-MM-DD / not a repo] |
| Runnable | [yes / probably / no — reason] |

## Vault Coverage
- **Distilled:** [yes (pass N, status X) / no]
- **Concepts:** [N notes, avg score X.X]
- **Top notes:** [titles with score ≥ 7]
- **Gaps:** [uncaptured patterns / none]
- **Summary:** [## Note from _index]

## Recommendation: [KEEP / ARCHIVE / NEEDS-TESTING]
[2-3 sentences with evidence]

### Next steps:
1. [action]
2. [action]
```
