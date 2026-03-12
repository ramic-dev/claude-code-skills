---
name: triage
description: Map and triage a large collection of personal data and projects. Scans
  directory structure using filesystem metadata (size, dates, extensions, git status)
  — does NOT read file contents. Produces a triage-report.md assigning each item a
  disposition: GitHub Public, GitHub Private, Cloud Storage, Delete, or needs /preserve
  scan. Use when the user wants to "map my projects", "figure out what to keep",
  "triage my files", "organize before deleting", "what should go on GitHub", or wants
  to audit a large personal archive before cleanup.
version: 1.0.0
context: fork
agent: general-purpose
allowed-tools: Bash, Glob, Grep, Write
argument-hint: [path]
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
du -sh "<ROOT>"/*/ 2>/dev/null | sort -rh | head -40
du -sh "<ROOT>" 2>/dev/null
```

Store: `TOTAL_SIZE`, top directories sorted by size with their sizes.

Also get file count:
```bash
find "<ROOT>" -type f 2>/dev/null | wc -l
```

Print: `Total: <SIZE> across <N> files`

---

## Phase 3 — File Type Distribution

```bash
find "<ROOT>" -type f 2>/dev/null \
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
find "<ROOT>" -type f \( -iname "*.mp4" -o -iname "*.avi" -o -iname "*.mov" -o -iname "*.mkv" \) \
  -exec du -sh {} + 2>/dev/null | sort -rh | head -10
```

---

## Phase 4 — Project Detection

Identify code project roots. A directory is a **project root** if it contains any of:
- `.git/` directory
- `package.json` / `composer.json` / `requirements.txt` / `Pipfile` / `Cargo.toml` / `go.mod` / `pom.xml` / `build.gradle` / `*.sln` / `*.csproj`
- `Makefile` / `CMakeLists.txt`
- `index.html` + (`js/` or `css/` or `src/`) — standalone web project
- A single dominant code extension (>60% of files) with >3 files

```bash
find "<ROOT>" -type f \( \
  -name ".git" -o -name "package.json" -o -name "composer.json" \
  -o -name "requirements.txt" -o -name "Cargo.toml" -o -name "go.mod" \
  -o -name "pom.xml" -o -name "Makefile" -o -name "CMakeLists.txt" \
  -o -name "*.sln" -o -name "Pipfile" \
\) 2>/dev/null | sed 's|/[^/]*$||' | sort -u
```

For each detected project root, collect:
```bash
# Size
du -sh "<project>" 2>/dev/null | cut -f1

# Is git repo?
git -C "<project>" rev-parse --git-dir 2>/dev/null && echo "yes" || echo "no"

# Has remote?
git -C "<project>" remote get-url origin 2>/dev/null || echo "none"

# Last commit
git -C "<project>" log -1 --format="%cr — %s" 2>/dev/null || echo "no commits"

# Primary language (dominant extension among code files)
find "<project>" -type f ! -path "*/.git/*" ! -path "*/node_modules/*" \
  | sed 's/.*\.//' | sort | uniq -c | sort -rn | head -1

# README exists?
test -f "<project>/README.md" && echo "yes" || echo "no"

# Has node_modules / vendor (cleanable weight)?
du -sh "<project>/node_modules" 2>/dev/null || true
du -sh "<project>/vendor" 2>/dev/null || true

# Sensitive markers (filenames only — do NOT read contents)
find "<project>" -type f \( \
  -name ".env" -o -name "*.env" -o -name "secrets.*" \
  -o -name "credentials.*" -o -name "*.pem" -o -name "*.key" \
  -o -name "id_rsa" -o -name "*.p12" \
\) ! -path "*/.git/*" 2>/dev/null
```

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
find "<dir>" -type f 2>/dev/null | sed 's/.*\.//' | tr '[:upper:]' '[:lower:]' \
  | sort | uniq -c | sort -rn | head -3
```

---

## Phase 6 — Junk Detection

Identify cleanable items across the entire ROOT:

```bash
# Orphaned node_modules (not under an active project)
find "<ROOT>" -name "node_modules" -type d 2>/dev/null \
  | while read d; do du -sh "$d" 2>/dev/null; done | sort -rh

# Python cache
find "<ROOT>" -name "__pycache__" -type d 2>/dev/null \
  | xargs du -sh 2>/dev/null | sort -rh | head -10

# macOS junk
find "<ROOT>" -name ".DS_Store" -type f 2>/dev/null | wc -l
find "<ROOT>" -name "Thumbs.db" -type f 2>/dev/null | wc -l

# Log files
find "<ROOT>" -name "*.log" -type f 2>/dev/null \
  | xargs du -sh 2>/dev/null | sort -rh | head -10

# Temp/build artifacts
find "<ROOT>" -type d \( -name "dist" -o -name "build" -o -name ".next" \
  -o -name "target" -o -name ".gradle" -o -name ".tox" \
  -o -name "coverage" -o -name ".nyc_output" \) 2>/dev/null \
  | while read d; do du -sh "$d" 2>/dev/null; done | sort -rh | head -20

# Duplicate directory names (same name appearing multiple times)
find "<ROOT>" -type d 2>/dev/null | sed 's|.*/||' | sort | uniq -d | head -10
```

Sum total cleanable size → `JUNK_TOTAL`.

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

1. **Never read file contents** — metadata only. The `Bash` tool runs `find`, `du`, `git log`, `wc` — never `cat`, `head`, `Read`.
2. **Sensitive file detection is filename-only** — never open `.env` or key files to check their contents.
3. **One Write call** for the report.
4. **Dispositions are recommendations** — use → prefix and clear reasoning so the user can override.
5. **Junk items listed individually** where possible — user needs to see exactly what will be deleted.
6. **No mid-scan questions** — if ambiguous, assign MANUAL REVIEW and explain why.
7. **Every directory accounted for** — nothing silently skipped.
