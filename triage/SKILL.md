---
name: triage
description: Map and triage a large collection of personal data and projects. Scans
  directory structure using filesystem metadata (size, dates, extensions, git status)
  — does NOT read file contents. Produces a triage-report.md assigning each item a
  disposition: GitHub Public, GitHub Private, Cloud Storage, Delete, or needs /preserve
  scan. Use when the user wants to "map my projects", "figure out what to keep",
  "triage my files", "organize before deleting", "what should go on GitHub", or wants
  to audit a large personal archive before cleanup.
version: 1.5.0
context: fork
agent: general-purpose
allowed-tools: Bash, Glob, Grep, Write
argument-hint: [path] [vault-path (default D:/knowledge)]
---

You are running the **triage** skill. Map a large directory of mixed personal data and projects using only filesystem metadata — never read file contents. Assign every item a disposition and produce `triage-report.md`.

Work autonomously through all 8 phases. Never ask clarifying questions mid-scan.

**If context pressure forces abbreviation**, prioritize: (1) write the report, (2) Action Plan section, (3) Code Projects table, (4) Junk/Cleanable table, (5) everything else.

---

## Phase 1 — Setup

- Resolve path: `$ARGUMENTS` if non-empty, else `.`
- `cd "<TARGET>" && pwd` → store as `ROOT`
- If invalid: stop and tell the user
- `df -h "<ROOT>" 2>/dev/null | tail -1` → note available disk space

---

## Phase 2 — Size Map

```bash
# Fallback if du fails: find + wc -c
du -sh "<ROOT>"/*/ 2>/dev/null | sort -rh | head -40 || true
du -sh "<ROOT>" 2>/dev/null || true
```

Store: `TOTAL_SIZE`, top directories sorted by size with their sizes.

Also get file count:
```bash
find "<ROOT>" -type f \
  ! -path "*/.git/*" ! -path "*/node_modules/*" ! -path "*/.godot/*" \
  ! -path "*/.gradle/*" ! -path "*/.venv/*" ! -path "*/venv/*" \
  ! -path "*/.claude/*" \
  2>/dev/null | wc -l
```

Print: `Total: <SIZE> across <N> files`

---

## Phase 3 — File Type Distribution

```bash
find "<ROOT>" -type f \
  ! -path "*/.git/*" ! -path "*/node_modules/*" ! -path "*/.godot/*" \
  ! -path "*/.gradle/*" ! -path "*/.venv/*" ! -path "*/venv/*" \
  ! -path "*/.claude/*" \
  2>/dev/null \
  | sed 's/.*\.//' | tr '[:upper:]' '[:lower:]' \
  | sort | uniq -c | sort -rn | head -30
```

Group extensions into categories and tally size per category:

| Category | Extensions | Approx size |
|----------|-----------|-------------|
| Code | js ts py php java go rs c cpp cs rb swift kt | — |
| Web | html css scss vue svelte | — |
| Data/Config | json yaml toml xml sql env | — |
| Docs | md txt pdf docx xlsx pptx | — |
| Images | jpg jpeg png webp gif bmp tiff svg | — |
| Video | mp4 avi mov mkv wmv flv webm | — |
| Audio | mp3 wav flac ogg aac m4a | — |
| Archives | zip tar gz 7z rar | — |
| Fonts | ttf otf woff woff2 | — |
| Junk | ds_store thumbs.db log tmp cache | — |

For video/audio/image-heavy categories, get size:
```bash
# Fallback if du fails: find + wc -c
find "<ROOT>" -type f \( -iname "*.mp4" -o -iname "*.avi" -o -iname "*.mov" -o -iname "*.mkv" \) \
  ! -path "*/.git/*" ! -path "*/node_modules/*" ! -path "*/.godot/*" \
  ! -path "*/.gradle/*" ! -path "*/.venv/*" ! -path "*/venv/*" \
  ! -path "*/.claude/*" \
  -exec du -sh {} + 2>/dev/null | sort -rh | head -10 || true
```

---

## Phase 4 — Project Detection

Identify code project roots. A directory is a **project root** if it contains any of:
- `.git/` directory
- `package.json` / `composer.json` / `requirements.txt` / `Pipfile` / `Cargo.toml` / `go.mod` / `pom.xml` / `build.gradle` / `*.sln` / `*.csproj` / `manifest.json`
- `Makefile` / `CMakeLists.txt`
- `index.html` + (`js/` or `css/` or `src/`) — standalone web project
- A single dominant code extension (>60% of files) with >3 files

```bash
# Detect project roots by manifest files (excluding .git — handled separately below)
find "<ROOT>" -type f \( \
  -name "package.json" -o -name "composer.json" \
  -o -name "requirements.txt" -o -name "Cargo.toml" -o -name "go.mod" \
  -o -name "pom.xml" -o -name "Makefile" -o -name "CMakeLists.txt" \
  -o -name "*.sln" -o -name "Pipfile" -o -name "manifest.json" \
\) ! -path "*/node_modules/*" ! -path "*/.godot/*" \
  ! -path "*/.gradle/*" ! -path "*/.venv/*" ! -path "*/venv/*" \
  ! -path "*/.claude/*" \
  2>/dev/null | sed 's|/[^/]*$||' | sort -u | tee /tmp/triage-manifest-projects.txt

# Detect git repos correctly (handles .git as dir, file/worktree, and submodules)
for d in "<ROOT>"/*/; do
  [ -d "$d" ] || continue
  git -C "$d" rev-parse --is-inside-work-tree >/dev/null 2>&1 && echo "$d"
done | sed 's|/$||' | sort -u | tee /tmp/triage-git-projects.txt
```

Merge both lists and deduplicate to get the final set of detected project roots.

For each detected project root, collect:
```bash
# Size
# Fallback if du fails: find + wc -c
du -sh "<project>" 2>/dev/null | cut -f1 || true

# Is git repo?
git -C "<project>" rev-parse --git-dir 2>/dev/null && echo "yes" || echo "no"

# Has remote?
git -C "<project>" remote get-url origin 2>/dev/null || echo "none"

# Last commit
git -C "<project>" log -1 --format="%cr — %s" 2>/dev/null || echo "no commits"

# Primary language (dominant extension among code files)
find "<project>" -type f ! -path "*/.git/*" ! -path "*/node_modules/*" \
  ! -path "*/.godot/*" ! -path "*/.gradle/*" ! -path "*/.venv/*" \
  ! -path "*/venv/*" ! -path "*/.claude/*" \
  | sed 's/.*\.//' | sort | uniq -c | sort -rn | head -1

# README exists?
test -f "<project>/README.md" && echo "yes" || echo "no"

# Has node_modules / vendor (cleanable weight)?
# Fallback if du fails: find + wc -c
du -sh "<project>/node_modules" 2>/dev/null || true
du -sh "<project>/vendor" 2>/dev/null || true

# Sensitive markers (filenames only — do NOT read contents)
find "<project>" -type f \( \
  -name ".env" -o -name "*.env" -o -name "secrets.*" \
  -o -name "credentials.*" -o -name "*.pem" -o -name "*.key" \
  -o -name "id_rsa" -o -name "*.p12" \
\) ! -path "*/.git/*" ! -path "*/.godot/*" ! -path "*/.gradle/*" \
  ! -path "*/.venv/*" ! -path "*/venv/*" ! -path "*/.claude/*" \
  2>/dev/null || true
```

After collecting per-project metadata, detect multi-version directories:

Store the merged, deduplicated project roots list from above into a file for reuse:
```bash
# Save detected projects to a temp file for reuse
# (combine both find-based and git-based detection, deduplicate)
sort -u /tmp/triage-manifest-projects.txt /tmp/triage-git-projects.txt > /tmp/triage-all-projects.txt 2>/dev/null || true

# Detect multi-version projects (v1/, v2/, backup/, etc.)
while IFS= read -r proj; do
  [ -d "$proj" ] || continue
  versions=$(ls -d "$proj"/v[0-9]* "$proj"/[0-9][0-9][0-9][0-9]-* "$proj"/backup* "$proj"/old* "$proj"/prototype* 2>/dev/null | wc -l)
  [ "$versions" -gt 1 ] && echo "MULTI-VERSION: $proj ($versions versions — recommend consolidation)"
done < /tmp/triage-all-projects.txt || true
```
*Note:* the manifest-file detection and git-repo detection commands from above should each redirect their output to `/tmp/triage-manifest-projects.txt` and `/tmp/triage-git-projects.txt` respectively, so that this loop can consume the combined list.

Flag multi-version projects in the triage report Code Projects table with `MULTI-VERSION` and the note **"consolidate before shipping"** in the Disposition column.

---

## Phase 4b — Vault Coverage Check

For each detected project, check whether it has already been distilled in the knowledge vault. The vault path is the **second argument** (`$ARGUMENTS` word 2), defaulting to `D:/knowledge` if not provided. Store it as `VAULT`.

```bash
# For each detected project, derive project-name from directory basename
PROJECT_NAME="$(basename "<project>")"
cat "$VAULT/_index/${PROJECT_NAME}.md" 2>/dev/null | head -5 || true
```

Parse the vault index note (if found) for `status:` and summary stats. If the vault note exists and its status is `done` or `distilled`, record it in the triage data as:
- **"already distilled (N concepts, avg score X.X)"** — extract concept count and average score from the index note frontmatter/body if available.

This information is added to the Code Projects table in the report (as an extra note in the Disposition column) and to the Action Plan. Projects that are already distilled are safe to archive or delete without running `/preserve` or `/distill` first.

If the vault directory does not exist or is empty, skip this phase silently.

---

## Phase 5 — Non-Project Directory Classification

For directories NOT identified as project roots, classify as:

- **Media collection** — >70% images/video/audio by file count, or >500MB of media
- **Document archive** — >70% PDFs/docs/spreadsheets
- **Font/asset bundle** — >50% fonts/design files
- **Backup/archive** — contains mostly `.zip .tar .7z .rar` or named `backup*`, `archive*`, `old*`
- **Junk/temp** — named `temp`, `tmp`, `cache`, `.cache`, `logs`, `__pycache__`, orphaned `node_modules`
- **Mixed/unknown** — everything else

```bash
# For each non-project directory, get dominant extension:
find "<dir>" -type f \
  ! -path "*/.git/*" ! -path "*/node_modules/*" ! -path "*/.godot/*" \
  ! -path "*/.gradle/*" ! -path "*/.venv/*" ! -path "*/venv/*" \
  ! -path "*/.claude/*" \
  2>/dev/null | sed 's/.*\.//' | tr '[:upper:]' '[:lower:]' \
  | sort | uniq -c | sort -rn | head -3
```

---

## Phase 6 — Junk Detection

Identify cleanable items across the entire ROOT:

```bash
# Orphaned node_modules (not under an active project)
find "<ROOT>" -name "node_modules" -type d \
  ! -path "*/.godot/*" ! -path "*/.gradle/*" ! -path "*/.venv/*" \
  ! -path "*/venv/*" ! -path "*/.claude/*" \
  2>/dev/null \
  | while read d; do du -sh "$d" 2>/dev/null; done | sort -rh || true

# Python cache
# Fallback if du fails: find + wc -c
find "<ROOT>" -name "__pycache__" -type d \
  ! -path "*/.godot/*" ! -path "*/.gradle/*" ! -path "*/.venv/*" \
  ! -path "*/venv/*" ! -path "*/.claude/*" \
  -print0 2>/dev/null \
  | xargs -0 -r du -sh 2>/dev/null | sort -rh | head -10 || true

# macOS junk
find "<ROOT>" -name ".DS_Store" -type f 2>/dev/null | wc -l
find "<ROOT>" -name "Thumbs.db" -type f 2>/dev/null | wc -l

# Log files
# Fallback if du fails: find + wc -c
find "<ROOT>" -name "*.log" -type f \
  ! -path "*/.git/*" ! -path "*/node_modules/*" ! -path "*/.godot/*" \
  ! -path "*/.gradle/*" ! -path "*/.venv/*" ! -path "*/venv/*" \
  ! -path "*/.claude/*" \
  -print0 2>/dev/null \
  | xargs -0 -r du -sh 2>/dev/null | sort -rh | head -10 || true

# Temp/build artifacts
find "<ROOT>" -type d \( -name "dist" -o -name "build" -o -name ".next" \
  -o -name "target" -o -name ".gradle" -o -name ".tox" \
  -o -name "coverage" -o -name ".nyc_output" \) \
  ! -path "*/.git/*" ! -path "*/node_modules/*" ! -path "*/.godot/*" \
  ! -path "*/.venv/*" ! -path "*/venv/*" ! -path "*/.claude/*" \
  2>/dev/null \
  | while read d; do du -sh "$d" 2>/dev/null; done | sort -rh | head -20 || true

# Duplicate directory names (same name appearing multiple times)
find "<ROOT>" -type d \
  ! -path "*/.git/*" ! -path "*/node_modules/*" ! -path "*/.godot/*" \
  ! -path "*/.gradle/*" ! -path "*/.venv/*" ! -path "*/venv/*" \
  ! -path "*/.claude/*" \
  2>/dev/null | sed 's|.*/||' | sort | uniq -d | head -10 || true

# Mixed-purpose directories (source + runtime artifacts in same dir)
for d in "<ROOT>"/*/; do
  [ -d "$d" ] || continue
  has_source=$(find "$d" -maxdepth 1 -type f \( -name "*.md" -o -name "*.py" -o -name "*.js" -o -name "*.php" -o -name "*.yml" \) 2>/dev/null | head -1)
  has_runtime=$(find "$d" -maxdepth 1 -type f \( -name "*.db" -o -name "*.sqlite" -o -name "*.log" -o -name "*.pid" \) 2>/dev/null | head -1)
  [ -n "$has_source" ] && [ -n "$has_runtime" ] && echo "MIXED: $(basename $d)/"
done || true
```

Sum total cleanable size → `JUNK_TOTAL`.

Flag mixed-purpose directories in the Cleanable Items table with `MIXED` and the note **"needs per-file .gitignore, not blanket directory ignore."**

---

## Phase 7 — Assign Dispositions

For each **code project**, assign one disposition using this decision tree:

**→ DELETE (safe)** if:
- No git history AND no unique code (only boilerplate/tutorial) AND last modified >2 years ago
- Is an `npm init` / `create-react-app` skeleton with no real content (src/ has <5 files, no logic)

**→ GITHUB PUBLIC** if ALL true:
- No sensitive file markers (no `.env`, `*.key`, `credentials.*`, etc.)
- No personal/client data signals (path doesn't contain: `client`, `lavoro`, `commessa`, `privato`, personal names)
- Contains reusable code, tools, experiments, or learning projects
- Content is general-purpose (not tied to a specific employer/client)

**→ GITHUB PRIVATE** if:
- Has sensitive file markers, OR
- Path or git remote suggests client/employer work, OR
- Contains personal data (photos, documents mixed in), OR
- Work-in-progress with no clear public value yet

**→ CLOUD STORAGE** if:
- Primarily media (photos, video, audio) with little or no code
- Large document archives
- Binary assets without source code

**→ NEEDS /preserve** if:
- Code project, no git remote, last modified >6 months ago — unknown value, needs content scan
- Language is unusual or path name suggests experimental/research work

**→ MANUAL REVIEW** if:
- Mixed content that doesn't fit above
- Unclear project type
- Very large (>1GB) with unclear structure

For **non-project directories**: assign CLOUD STORAGE, DELETE, or MANUAL REVIEW using the same signals.

---

## Phase 8 — Write `triage-report.md`

Write to `<ROOT>/triage-report.md` (single Write call).

````markdown
# Triage Report

**Generated:** <YYYY-MM-DD>
**Scanned path:** <ROOT>
**Total size:** <TOTAL_SIZE> across <N> files
**Potential recoverable space:** ~<JUNK_TOTAL> (junk/cleanable)

---

## Size Map — Top Directories

| Directory | Size | Category | Disposition |
|-----------|------|----------|-------------|
| `dir` | X GB | Code projects | → GitHub |
| `dir` | X GB | Media | → Cloud |
| ... | | | |

---

## Code Projects (<N> found)

| Project | Size | Language | Last Commit | Git Remote | README | Sensitive | Disposition |
|---------|------|----------|-------------|-----------|--------|-----------|-------------|
| `path` | X MB | JS | 3 months ago | none | no | no | → GitHub Public |
| `path` | X MB | PHP | 2 years ago | github.com/... | yes | .env | → GitHub Private |
| `path` | X MB | Python | unknown | none | no | no | → /preserve |

---

## Media & Document Collections (<N> found)

| Directory | Size | Dominant Type | File Count | Disposition |
|-----------|------|--------------|------------|-------------|
| `path` | X GB | JPEG photos | 2,400 | → Cloud Storage |

---

## Cleanable Items (~<JUNK_TOTAL> recoverable)

| Item | Size | Type | Action |
|------|------|------|--------|
| `path/node_modules` | X MB | Orphaned npm deps | Delete |
| `path/__pycache__` | X MB | Python cache | Delete |
| N × `.DS_Store` files | — | macOS junk | Delete |
| `path/dist/` | X MB | Build artifact | Delete (rebuild anytime) |

---

## Manual Review Needed (<N> items)

| Path | Size | Why unclear |
|------|------|-------------|
| `path` | X MB | Mixed media + code, no project markers |

---

## Action Plan

### → GitHub Public (<N> projects)
- `path` — <language>, <brief description from dir name/README>

### → GitHub Private (<N> projects)
- `path` — <reason: sensitive markers / client work / personal>

### → Run /preserve first (<N> projects)
These have potential value but need a content scan before deciding:
- `path` — <why: no remote, old, unusual language>

### → Cloud Storage (<size>)
- `path` — <X GB of photos/video/docs>

### → Delete (<size> recoverable)
**Junk (safe to delete):**
- `path/node_modules`, `path/__pycache__`, etc.

**Projects (verify before deleting):**
- `path` — <reason: boilerplate skeleton, no content, 2+ years untouched>

### → Manual Review (<N> items)
- `path` — <what's unclear>

---

## Summary

<3–5 sentences: total situation, biggest wins (largest junk pile, most at-risk projects), recommended first action.>
````

---

## Absolute Rules

1. **Never read file contents of the scanned directory** — metadata only. The `Bash` tool runs `find`, `du`, `git log`, `wc` — never `cat`, `head`, `Read` on target files. Exception: Phase 4b reads vault index notes (outside the scanned directory) to check distillation status.
2. **Sensitive file detection is filename-only** — never open `.env` or key files to check their contents.
3. **One Write call** for the report.
4. **Dispositions are recommendations** — use → prefix and clear reasoning so the user can override.
5. **Junk items listed individually** where possible — user needs to see exactly what will be deleted.
6. **No mid-scan questions** — if ambiguous, assign MANUAL REVIEW and explain why.
7. **Every directory accounted for** — nothing silently skipped.
