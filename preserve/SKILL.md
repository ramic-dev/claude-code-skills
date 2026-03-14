---
name: preserve
description: Scan every file in a project directory and generate a preservation report
  identifying rare, unique, or valuable content worth archiving. Use when the user asks
  to "preserve the project", "scan for unique code", "find rare ideas", "generate a
  preservation report", "document what's worth keeping", "audit project knowledge", or
  wants to catalog experimental/prototype/domain-specific content before a migration,
  cleanup, or handoff.
version: 6.4.0
context: fork
agent: general-purpose
allowed-tools: Read, Grep, Glob, Bash, Write
argument-hint: [path]
---

You are running the **preserve** skill. Scan a project directory, read every file you can, evaluate each for uniqueness and rarity, and produce `preservation-report.md` identifying the content most worth saving before it is lost.

Complete all 9 phases in order. Never ask clarifying questions — work autonomously.

**Portability:** all bash commands must work on Linux, macOS, AND Windows (Git Bash). Use `|| true` on any command that may exit non-zero when nothing matches (ls globs, find, gh). Use `find -print0 | xargs -0` instead of `xargs -d '\n'` (macOS xargs doesn't support `-d`).

**If context pressure forces abbreviation**, prioritize in this order: (1) write the report, (2) TOP 10 entries, (3) score breakdowns, (4) inventory tables, (5) Summary Observations, (6) Recommendations. Never skip Phase 1, 8, or 9.

---

## Phase 1 — Setup & Checkpoint Check

- Resolve path: use `$ARGUMENTS` if non-empty, else `.`
- Run `cd "<TARGET_PATH>" && pwd` to get absolute `ROOT`
- If path invalid: stop and tell the user

**Checkpoint:** `test -f "<ROOT>/.preserve-progress.json" && cat "<ROOT>/.preserve-progress.json" | head -5`
- If `version` field differs from current skill version (`6.4.0`): print `Checkpoint from older version, starting fresh` and delete it
- If timestamp < 4h ago and version matches: print `Resuming from Phase <N+1>...` and skip completed phases
- If timestamp ≥ 4h: print `Stale checkpoint, starting fresh` and delete it

**Previous report:** `test -f "<ROOT>/preservation-report.md" && grep "^\*\*Generated" "<ROOT>/preservation-report.md" | head -1`
- If found: archive it — `mv preservation-report.md preservation-report-<extracted-date>.md`
- Fallback if date unextractable: `mv preservation-report.md preservation-report-$(date -r preservation-report.md +%Y-%m-%dT%H%M%S 2>/dev/null || date +%Y-%m-%dT%H%M%S).md`
- Extract previous TOP 10 paths via `grep "^### #[0-9]" <archived> | sed 's/.*\`\(.*\)\`.*/\1/'` → store as `PREV_TOP10` (set `[]` on failure)

---

## Phase 2 — File Discovery & Cost Estimation

```bash
find "<ROOT>" -type f \
  ! -path "*/.git/*" ! -path "*/node_modules/*" ! -path "*/__pycache__/*" \
  ! -path "*/dist/*" ! -path "*/build/*" ! -path "*/vendor/*" \
  ! -path "*/.next/*" ! -path "*/.venv/*" ! -path "*/venv/*" \
  ! -path "*/.tox/*" ! -path "*/coverage/*" ! -path "*/.nyc_output/*" \
  ! -path "*/.cache/*" ! -path "*/target/*" ! -path "*/.gradle/*" \
  ! -path "*/.godot/*" ! -path "*/.claude/*" \
  2>/dev/null | sort
```

Store count as `N_TOTAL`. Choose strategy:
- `< 100` → **FULL** (read all non-skipped TEXT files)
- `100–399` → **SELECTIVE** (grep pre-scan, full-read high-signal, strategic-read rest)
- `≥ 400` → **SAMPLED** (pre-scan, full-read top 80, strategic-read next 60, SAMPLED rest)

**Git detection:** `git -C "<ROOT>" rev-parse --git-dir 2>/dev/null && echo yes || echo no` → store as `IS_GIT_REPO`

**Mixed-purpose detection:** check if ROOT contains both source and runtime artifacts in the same directory:
```bash
find "<ROOT>" -maxdepth 3 -type d 2>/dev/null | while IFS= read -r d; do
  [ "$d" = "<ROOT>" ] && continue
  has_source=$(find "$d" -maxdepth 1 -type f \( -name "*.md" -o -name "*.py" -o -name "*.js" -o -name "*.php" -o -name "*.yml" \) 2>/dev/null | head -1)
  has_runtime=$(find "$d" -maxdepth 1 -type f \( -name "*.db" -o -name "*.sqlite" -o -name "*.log" -o -name "*.pid" \) 2>/dev/null | head -1)
  [ -n "$has_source" ] && [ -n "$has_runtime" ] && echo "MIXED: $d/"
done || true
```
If mixed-purpose directories are found, note them in the Summary Observations section of the report: these directories risk accidentally committing runtime artifacts and should have `.gitignore` rules added.

**Cost estimate:** sample `find ... -print0 2>/dev/null | xargs -0 -r wc -l 2>/dev/null | head -50` to get `avg_lines`. Then:
- `full_read_sec = avg_lines / 350` per file · `strategic = 2s` · `native = 10s`
- Print: `Strategy: X | ~<N_full> full + <N_strategic> strategic + <N_native> native reads | ~<X>–<Y> min`
- If total > 900s: warn `⚠ Large project — scan may take 15+ minutes`

Save checkpoint: `{ "version":"6.4.0", "root":"<ROOT>", "phase_completed":2, "strategy":"<S>", "is_git_repo":<bool>, "scored_files":[], "timestamp":"<ISO>" }` → `<ROOT>/.preserve-progress.json`

---

## Phase 3 — Partition Files by Type

**UNREADABLE** (do NOT read):
- Executables/libs: `.exe .dll .so .dylib .obj .o .a .lib .bin .com .sys .msi .app .apk .pck`
- Archives: `.zip .tar .gz .tgz .bz2 .7z .rar .xz .cab .iso .dmg .pkg .deb .rpm`
- Audio: `.mp3 .wav .flac .ogg .aac .wma .m4a .opus .mid .midi`
- Video: `.mp4 .avi .mov .mkv .wmv .flv .webm .m4v .3gp .ts`
- Binary images: `.ico .cur .xcf .psd .psb .raw .cr2 .nef .arw .dng`
- Design/3D: `.ai .sketch .fig .xd .indd .eps .svgz .glb .gltf .blend`
- Office: `.docx .xlsx .pptx .doc .xls .ppt .odt .ods .odp .pages .numbers .key`
- Database: `.db .sqlite .sqlite3 .mdb .accdb .frm .ibd`
- Bytecode: `.pyc .pyo .class .wasm .beam .luac .elc`
- ML/data: `.pkl .pickle .npy .npz .h5 .hdf5 .model .weights .onnx .pb .pt .pth .joblib .safetensors`
- Fonts: `.ttf .otf .woff .woff2 .eot`
- Certs/keys: `.p12 .pfx .der .cer .crt .keystore`

**NATIVE** (Claude reads natively): `.pdf` | `.jpg .jpeg .png .webp .gif .bmp .tiff .tif`

**TEXT**: everything else

**Unknown/missing extension heuristic:** do NOT use `file` command — it misclassifies proprietary JSON formats (`.dam`, `.scene`, `.ron`) as binary. Instead:
```bash
LC_ALL=C tr -d '\0' < <(head -c 512 "<path>" 2>/dev/null) | wc -c
# Compare with: wc -c < <(head -c 512 "<path>" 2>/dev/null)
```
- If both byte counts are equal → TEXT (no null bytes) · If stripped count < original → UNREADABLE (contains null bytes) · Command fails → UNREADABLE (`Read probe failed`)
- **Portability note:** do NOT use `grep -P` (macOS grep lacks `-P`). The `tr -d '\0'` approach works on Linux, macOS, and Git Bash.

**Classification is final:** once a file is assigned TEXT (null-byte check passes + Read succeeds), it stays TEXT permanently. It must appear ONLY in the "Text Files Analyzed" table — never in "Unreadable Files". If the file's *content* contains embedded binary data (base64 blobs, encoded fields, binary-in-JSON), that is content to analyze, not a reason to reclassify. The Unreadable table is for files that CANNOT be read, not for files whose content happens to encode binary data.

Print: `TEXT: <N> | NATIVE: <N> | UNREADABLE: <N>`

---

## Phase 4 — Pre-Screen: Auto-Skip

Mark as **SKIPPED** (do not read or score):
- **Lock files:** `package-lock.json yarn.lock poetry.lock Gemfile.lock Cargo.lock composer.lock pnpm-lock.yaml *.lock *.lockb`
- **Minified:** `*.min.js *.min.css *-min.js *-min.css`
- **Source maps:** `*.map`
- **Generated `.d.ts`:** only if matching `.ts` exists in same directory
- **Empty:** `find "<ROOT>" -empty -type f 2>/dev/null || true`
- **Auto-generated content** (check first 8 lines): `THIS FILE IS AUTO-GENERATED`, `DO NOT EDIT`, `Code generated by`, `@generated`, `# AUTOGENERATED`, `// Generated by`

Record each with reason: `Lock file` / `Minified` / `Auto-generated` / `Empty` / `Source map`

---

## Phase 5 — Grep Pre-Scan (SELECTIVE and SAMPLED only)

Run these Grep searches across all TEXT files (`output_mode: files_with_matches`). Sum matched points per file → **pre-scan score**.

| Group | Signal | Pattern | Pts |
|-------|--------|---------|-----|
| A | Experimental markers | `EXPERIMENTAL\|POC\|PROOF.OF.CONCEPT\|PROTOTYPE` | +3 |
| A | ADR structure | `## (Context\|Decision\|Consequences\|Status)` | +3 |
| A | WIP/Draft/Idea | `\bWIP\b\|\bDRAFT\b\|\bIDEA\b\|\bSPIKE\b\|\bSKETCH\b` | +2 |
| B | Algorithm concepts (ci) | `algorithm\|heuristic\|approximat\|theorem\|lemma\|invariant` | +2 |
| B | Math functions (ci) | `sqrt\|log2\|sigmoid\|entropy\|variance\|eigenval\|factorial` | +2 |
| B | Math idioms (ci) | `f64\|f32\|float64\|numpy\|ndarray\|matrix\|tensor` | +1 |
| C | Hack/workaround | `HACK:\|WORKAROUND:\|monkey.patch\|kludge\|bandaid` | +2 |
| C | Long important comment | `(NOTE:\|FIXME:\|XXX:).{40,}` | +1 |
| D | Medical domain (ci+ctx)* | `dosage\|diagnosis\|pathogen\|symptom\|prognosis\|contraindication` | +2 |
| D | Legal/financial (ci+ctx)* | `compliance\|liability\|arbitrage\|ledger\|amortiz\|collateral` | +2 |
| D | Engineering/sci (ci+ctx)* | `torque\|resonance\|impedance\|oscillat\|viscosity\|eigenvalue` | +2 |
| E | Prompt templates | `\{\{.+\}\}\|\[INST\]\|system_prompt` | +2 |

> **Note (Group E, `{{ }}` pattern):** Exclude `.twig`, `.jinja2`, `.j2`, `.hbs`, `.mustache`, `.html` files from this pattern — `{{ }}` is standard template syntax in Twig, Jinja2, Handlebars, and Angular, NOT an LLM prompt indicator. Only match `{{ }}` in `.txt`, `.md`, `.py`, `.js`, `.ts` files.
| E | Seeds/generative | `random_seed\|seed=\|np\.random\|torch\.manual_seed\|faker` | +1 |
| F | Rust unsafe | `unsafe\s*\{` | +2 |
| F | Python metaprogramming | `__slots__\|__init_subclass__\|__class_getitem__` | +2 |
| F | FFI/cross-language | `\bFFI\b\|ctypes\|jni\|JNI\|extern "C"` | +2 |
| F | Go concurrency | `\bgoroutine\b\|\bchan\b.*<-\|select\s*\{` | +1 |
| F | Decorators/annotations | `@(abstractmethod\|overload\|property\|staticmethod)` | +1 |
| H | Non-English markers (ci) | `\b(NOTA\|ATTENZIONE\|IMPORTANTE\|REMARQUE\|HINWEIS\|ACHTUNG\|WICHTIG\|ATENCIÓN):` | +2 |
| H | Dense comment block | ≥ 8 lines matching `^\s*(//\|#\|--\|/\*\|\*).{50,}` | +1 |

*Group D: domain term must appear on same line as code-logic syntax (`=`, `(`, `if`, `return`, `->`, etc.) to avoid false positives from import names.

**Git aging (Group G — only if `IS_GIT_REPO = true`, only for files with pre-scan score ≥ 1):**
Run `git -C "<ROOT>" log --follow -1 --format="%cr" -- "<file>"` per file.
- Empty (untracked) or "N years ago" (N≥2): +2 · "1 year ago" or ≥8 months: +1 · recent: +0
- Also store: `git -C "<ROOT>" log --follow -1 --format="%cr by %an — %s" -- "<file>"` as `git_last`

**Apply scores:**
- SELECTIVE: score ≥ 1 → FULL read; score 0 → STRATEGIC read
- SAMPLED: top 80 by score → FULL; next 60 → STRATEGIC; rest → SAMPLED
- SAMPLED only: also pull 10 random files from score-0 pool (`shuf | head -10`) → FULL (wildcard); mark as `Full (wildcard)` in inventory

Update checkpoint after Phase 5.

---

## Phase 6 — Read, Analyze & Fingerprint

**Resume:** if checkpoint has `phase_completed=6`, skip files already in `scored_files`.
**Checkpoint cadence:** update `.preserve-progress.json` every 10 files scored.

Process TEXT files (descending pre-scan score), then NATIVE files.

**Read modes:**
- FULL: `Read` tool, entire file
- STRATEGIC: Read lines 1–120, then Grep Phase 5 patterns on this file, then Read ±10 lines around each match
- NATIVE: `Read` tool natively (Claude processes PDF/images); on error → UNREADABLE

**Errors:**

| Condition | Action |
|-----------|--------|
| Permission denied | UNREADABLE: `Permission denied` |
| Too large / timeout | Downgrade to STRATEGIC; if still fails → SAMPLED |
| Binary mid-read | Stop, reclassify UNREADABLE: `Binary content despite text extension` |
| File gone | UNREADABLE: `File disappeared during scan` |

Never retry a failed read.

### Scoring formula

Start at **0**. Floor = 0, ceiling = 10.

**Mutual exclusion:** for each distinct code block, award at most ONE bonus from Tier A; for the whole file, award at most ONE bonus from Tier B. Tier C bonuses each apply independently.

```
TIER A — Intellectual content (highest applicable per code block)
+3  Custom algorithm / data structure from scratch (no stdlib equivalent)
+3  Architecture Decision Record (context / decision / consequences)
+3  Mathematical formula implemented from scratch (formula is in the code)

TIER B — Domain & intent (highest applicable per file)
+2  Domain-specific terminology in logic/comments (with code-syntax adjacency)
+2  Creative/generative content (prompts, seeds, templates, original assets with no source)
+2  Unique business logic not reducible to standard CRUD

TIER C — Design & risk (each independent)
+2  Experimental / prototype / WIP markers in content
+2  Non-obvious config — configuration values whose purpose or rationale is non-trivial; does NOT require NOTE:/HACK: comments, evaluate from semantics (e.g. a single CSS variable that controls all layout dimensions, a startup flag that alters GC behavior)
+2  Workaround / monkey-patch — non-obvious clever logic with no standard equivalent; does NOT require HACK: comment, evaluate from semantics (e.g. a bootstrap that purges DOM scripts then parallel-fetches libraries via eval, a function that re-enters an event loop to flush microtasks)
+2  Research note, design doc, changelog with rationale
+2  Cross-language boundary code (FFI, JNI, ctypes, extern "C")
+2  Unsafe block (Rust) or equivalent dangerous-but-necessary code
+2  Untracked by git — lost on fresh clone (only if IS_GIT_REPO)
+2  Last git commit ≥ 2 years ago (only if IS_GIT_REPO)
+1  HACK:/NOTE:/FIXME: with ≥ 2 lines explanation (per instance, max +3 total)
+1  Last git commit 8–23 months ago (only if IS_GIT_REPO)
+1  Sole file of its type in the project
+1  File's basename (not directory path) contains: experimental, draft, sketch, idea, old, legacy, dont-delete

PENALTIES
−2  Standard CRUD boilerplate (basic REST handler, trivial getter/setter)
−2  Auto-generated type definitions or schemas
−2  Obvious starter / tutorial template
−1  Config with no explanatory comments (pure key=value)
−3  Near-duplicate of a higher-scored file (Phase 7 fingerprint)
```

*Example:* `css/exploration.css` coin-flip animation → award +3 (Tier A: custom algorithm), NOT also +2 (Tier B: creative). The animation required algorithmic construction, not just artistic intent — Tier A wins.

**Fingerprint:** after scoring, run Grep pattern `^\s*(def |fn |func |function |class |struct |impl |type |interface )\s*\w+` on the file. Collect up to 20 matches, normalize to lowercase identifier names → `fingerprint: [...]`.

Record: `{ path, category, read_mode, lines, score, score_breakdown, key_finding, fingerprint, git_last }`

---

## Phase 7 — Deduplicate, Rank, Select TOP 10

**Deduplication:** for every pair of files with score ≥ 3:
1. `overlap = shared_identifiers / min(len_A, len_B)`
2. If `overlap ≥ 0.60` AND same/adjacent directory: apply −3 to lower-scored file, note `Near-duplicate of <path> (overlap: XX%)`. If adjusted score ≤ 1, exclude from TOP 10 (keep in inventory).
3. Skip if either fingerprint is empty (config/data files).

**Ranking:** sort by score desc. Ties: (1) higher line count → (2) fewer path segments from ROOT → (3) alphabetical.

**Category cap:** max 4 NATIVE (PDF/image) slots in TOP 10. If more than 4 NATIVE files rank naturally, keep the 4 highest-scoring and fill remaining slots with next-best TEXT files.

**Vault cross-reference (optional):** if a vault exists at `D:/knowledge` (or a user-specified path), spot-check whether top-scored concepts are already captured:
```bash
# Quick vault cross-reference for top findings
grep -rl "<keyword-from-finding>" "D:/knowledge/notes/" 2>/dev/null | head -3 || true
```
If a finding is already in the vault, add a note in the report: `[already in vault: <slug> (score N)]`. This helps the user know which rare content is already safe and which still needs preservation. Keep this lightweight — just grep for key terms from each top entry, don't read every note.

After applying category cap, select top 10. If fewer than 10 candidates remain (due to cap, deduplication, or low total scored files), include all available — never pad with empty or placeholder entries. Adjust the report header to match the actual count: write `## TOP 7 MOST VALUABLE ITEMS` if only 7 qualify. Note the shortfall in the report header line: `*(category cap reduced pool — N/10 slots filled)*`.

---

## Phase 8 — Write `preservation-report.md`

Write to `<ROOT>/preservation-report.md` (single Write call).

**Inventory truncation:** Text Files table: show all score ≥ 1; collapse score-0 rows to `*(N files scored 0 — omitted)*`. Sampled Files table: show pre-scan score ≥ 1; collapse score-0 to `*(N files, score 0 — not read)*`. NATIVE, Skipped, Unreadable: show all.

**Header counts:** derive all counts by tallying the final inventory tables, not from running totals. Specifically: "Text files — fully read/strategically read/sampled" = count rows in Text Files Analyzed by Read column value (including the collapsed score-0 count); "PDF / image files read" = count rows in PDF / Image Files Read table; "Files skipped" = count rows in Skipped Files table; "Unreadable files" = count rows in Unreadable Files table. Recount before writing — never carry forward an intermediate count.

````markdown
# Project Preservation Report

**Generated:** <YYYY-MM-DD>
**Scanned path:** <ROOT>
**Scan strategy:** <FULL | SELECTIVE | SAMPLED>
**Total files discovered:** <N_TOTAL>
**Previous report:** <filename | none>

| Category | Count |
|----------|-------|
| Text files — fully read | N |
| Text files — strategically read | N |
| Text files — sampled (not scored) | N |
| PDF / image files read | N |
| Files skipped | N |
| Unreadable files | N |

---

## Changes Since Last Scan
*(Omit if no previous report)*

| Change | File | Detail |
|--------|------|--------|
| 🆕 New | `path` | Was not in previous TOP 10 |
| ⬆ ⬇ Score | `path` | Was X/10, now Y/10 |
| ❌ Dropped | `path` | Now scores Z/10 |

---

## TOP 10 MOST VALUABLE ITEMS

### #1 — `<relative/path>`
**Score:** X/10 | **Read mode:** Full/Strategic | **Lines:** N
**Score breakdown:** +3 Tier A custom algorithm, +2 Tier C workaround, −1 penalty = raw X → X/10
**Why it matters:** <2–4 sentences, specific, cite identifiers>

**Key snippet:**
```
<exact quote, 5–15 lines>
```

**Preservation action:** <specific — name function, target file, action>

---
### #2 … #10 (repeat)

---

## Full File Inventory

### Text Files Analyzed
| File | Lines | Read | Score | Last Git Activity | Key Finding |
|------|-------|------|-------|-------------------|-------------|
| `src/algo.py` | 312 | Full | 8 | 3 years ago by alice | Custom Dijkstra with domain-specific decay |
| *(N files scored 0 — omitted)* | | | | | |

For files scoring ≥ 1 that are NOT in the TOP 10, append a brief score rationale in the Key Finding cell: e.g. `[+1 sole .proto in project] Protobuf schema for UserAuth message`. This makes the inventory self-explanatory without a full breakdown.

*(Omit "Last Git Activity" column if IS_GIT_REPO = false)*

### PDF / Image Files Read
| File | Type | Score | Key Finding |
|------|------|-------|-------------|

### Sampled Files (Not Scored)
| File | Pre-scan Score | Note |
|------|---------------|------|
| *(N files, score 0 — not read)* | | |

### Skipped Files
| File | Reason |
|------|--------|

### Unreadable Files
| File | Extension | Category | Notes |
|------|-----------|----------|-------|

---

## Preservation Recommendations

### Immediate Priority (Score 8–10)
- `path` — <action>

### Worth Archiving (Score 5–7)
- `path` — <action>

### Low Priority (Score 0–4)
- `path` — <action>

### Unreadable Assets Worth Converting
- `path` — <conversion>

---

## Summary Observations

<3–6 sentences: domain, unique knowledge at risk, what surprised you. Cite actual filenames.>
````

After writing: `rm -f "<ROOT>/.preserve-progress.json"`

---

## Phase 9 — Console Summary

```
Preservation scan complete.
Report: <ROOT>/preservation-report.md

TOP 5:
  #1  X/10  path  —  <one-line reason>
  #2  X/10  path  —  <one-line reason>
  #3  X/10  path  —  <one-line reason>
  #4  X/10  path  —  <one-line reason>
  #5  X/10  path  —  <one-line reason>

Files: <N_full> read · <N_strategic> strategic · <N_sampled> sampled · <N_skipped> skipped · <N_unread> unreadable
[Previous report archived as: preservation-report-<date>.md]  ← omit if none existed
```

---

## Absolute Rules

1. **Never read UNREADABLE files.** Binary mid-read → stop, reclassify, move on.
2. **Snippets are exact quotes** — never paraphrase.
3. **Preservation actions are specific** — name function, target, action. Never "consider saving this."
4. **Score breakdowns shown** for every TOP 10 entry, including tier labels.
5. **One Write call** for the report.
6. **No mid-scan questions** — deliver the finished report.
7. **Sampled files with pre-scan score ≥ 1** are always listed individually.
8. **Every error recorded** with exact message — nothing silently swallowed.
9. **Checkpoint cleaned up** after successful run.
