---
name: distill
description: Extract and document all unique ideas, algorithms, patterns, and non-obvious
  knowledge from a project into atomic knowledge notes. Unlike /preserve (which saves
  files), /distill saves concepts — the reasoning, decisions, and insights that cannot
  be reconstructed from scratch. Each concept becomes a separate markdown file with
  YAML frontmatter, compatible with Obsidian + Dataview for search and filtering.
  Supports multiple passes — on re-run, extends existing notes rather than overwriting.
  Use when you want to "extract ideas before deleting a project", "document what I
  learned from this codebase", "capture unique knowledge", "distill project insights",
  or "build a knowledge base" from existing code.
version: 3.0.0
context: fork
agent: general-purpose
allowed-tools: Read, Grep, Glob, Bash, Write
argument-hint: [path] [output-vault]
---

You are running the **distill** skill. Read every file in a project, extract every non-obvious concept, and write one markdown file per concept to a central knowledge vault — compatible with Obsidian + Dataview.

**Core principle:** files are reconstructable, ideas are not. Each note must be self-contained: a competent developer with no access to the original code must be able to understand and re-implement the concept from the note alone.

**Multiple passes:** this skill is designed to run multiple times on the same project. On each run it reads existing vault notes first and only adds or extends — never overwrites.

Work through all 8 phases autonomously. Never ask clarifying questions.

**If context pressure forces abbreviation**, write notes extracted so far, then the index. Never skip Phase 1 or 8.

---

## Phase 1 — Setup & Existing Knowledge Load

Parse `$ARGUMENTS`:
- First token (if present): `SOURCE_PATH` — project to distill. Default: `.`
- Second token (if present): `VAULT_PATH` — output vault. Default: `~/knowledge`

```bash
cd "<SOURCE_PATH>" && pwd          # → ROOT
basename "<ROOT>"                  # → PROJECT_NAME
mkdir -p "<VAULT_PATH>/<PROJECT_NAME>"
mkdir -p "<VAULT_PATH>/_index"
```

**Load existing notes** — read every `.md` file already in `<VAULT_PATH>/<PROJECT_NAME>/`:
```bash
ls "<VAULT_PATH>/<PROJECT_NAME>/" 2>/dev/null
```
For each existing file, read it and extract:
- `title` from frontmatter → add to `KNOWN_TITLES` set
- Full body → add to `KNOWN_NOTES` map (filename → content)

This set is the deduplication memory for this run. Print: `Note esistenti: N | Progetto: PROJECT_NAME`

**Pipeline status:** check if `<VAULT_PATH>/_index/<PROJECT_NAME>.md` exists.
- If yes: read its `status` field → print `Stato pipeline: <status>`
- Update status to `wip` in the index file (or create it with `status: wip` if missing)

---

## Phase 2 — File Discovery & Partition

```bash
find "<ROOT>" -type f \
  ! -path "*/.git/*" ! -path "*/node_modules/*" ! -path "*/__pycache__/*" \
  ! -path "*/dist/*" ! -path "*/build/*" ! -path "*/vendor/*" \
  ! -path "*/.next/*" ! -path "*/.venv/*" ! -path "*/venv/*" \
  ! -path "*/target/*" ! -path "*/.gradle/*" ! -path "*/coverage/*" \
  2>/dev/null | sort
```

**Partition:**
- **SKIP:** lock files, minified (`*.min.js *.min.css`), source maps (`*.map`), empty files, auto-generated (first 8 lines: `THIS FILE IS AUTO-GENERATED` / `DO NOT EDIT` / `@generated`), licenses (`LICENSE* COPYING*`), fonts (`.ttf .otf .woff .woff2`), compiled (`.o .pyc .class`)
- **NATIVE:** `.pdf .jpg .jpeg .png .webp .gif`
- **Unknown extension:** `head -c 512 "<path>" 2>/dev/null | LC_ALL=C grep -cP '\x00'` → 0 = TEXT, >0 = SKIP
- **TEXT:** everything else

Print: `Da leggere: N_TEXT testo + N_NATIVE immagini/PDF | Saltati: N_SKIP`

---

## Phase 3 — Priority Pre-Scan

```bash
grep -rl "HACK:\|WORKAROUND:\|monkey.patch\|kludge" "<ROOT>" 2>/dev/null
grep -rl "algorithm\|heuristic\|approximat\|theorem\|invariant" "<ROOT>" -i 2>/dev/null
grep -rl "EXPERIMENTAL\|POC\|WIP\|DRAFT\|SPIKE" "<ROOT>" -i 2>/dev/null
grep -rl "eval\|Function(\|__import__\|ctypes\|FFI\|unsafe" "<ROOT>" 2>/dev/null
grep -rl "Math\.\(random\|sin\|cos\|sqrt\|pow\|log\)\|sigmoid\|entropy" "<ROOT>" -i 2>/dev/null
```

Files matching multiple signals → read first.

---

## Phase 4 — Read & Extract Concepts

For each file, ask: **"Would a competent developer say 'obvious' or 'interesting — I wouldn't have thought of that'?"**

*Interesting* → extract. *Obvious* → skip.

### Categories

| `category` | What qualifies |
|------------|---------------|
| `algoritmo` | Non-standard computation, custom data structure, formula from scratch, unexpected optimization |
| `pattern-architetturale` | Unusual component communication, inverted data flow, non-standard layering |
| `hack` | Workaround for platform/library limitation, non-obvious sequencing, polyfill |
| `conoscenza-di-dominio` | Business rules, thresholds, ratios that encode hard-won domain expertise |
| `decisione` | Why something non-standard was chosen — especially when the default seems simpler |
| `frammento` | Code so short and dense that quoting it directly is the most efficient representation (≤8 lines) |

### Not worth extracting
Standard CRUD, libraries used as intended, boilerplate, self-evident config, standard patterns used standardly, anything a competent developer arrives at in <5 minutes.

### Per-concept deduplication (apply before writing each note)

For each extracted concept, compare its title and description against `KNOWN_TITLES` and `KNOWN_NOTES`:

**Case A — Title not in KNOWN_TITLES:** concept is new → create new file.

**Case B — Title matches or is very similar (same idea, same project):**
- Compare new description against existing note body
- If the new pass found **no additional information** → skip entirely, do not write
- If the new pass found **genuinely new details** (new context, edge case, additional example, correction) → mark as UPDATE: append an `## Integrazione (YYYY-MM-DD)` section to the existing file with only the new information. Update `updated` in frontmatter.

**Case C — Same concept, different project:** create new file with different `project` field. These are separate notes — same idea appearing in two projects is itself interesting.

---

## Phase 5 — Native Files

View each NATIVE file with the Read tool. Extract a note only if the file contains original creative work with non-obvious choices (game map with specific parameters, diagram with non-derivable knowledge). Generic stock images, icons, screenshots: no note.

---

## Phase 6 — Deduplication Pass

After extracting all concepts for this run:
- If two newly-extracted concepts describe the same idea → merge into one note, list both source files
- Review new notes against KNOWN_NOTES one more time for any missed overlaps

---

## Phase 7 — Decide Action Per Note

Classify each note from this run:

| Action | Condition | What to write |
|--------|-----------|---------------|
| `CREATE` | New concept (Case A) | Full new file |
| `EXTEND` | Existing + new details (Case B with additions) | Append `## Integrazione` section to existing file |
| `SKIP` | Existing + nothing new (Case B, no additions) | Nothing |

---

## Phase 8 — Write Files & Update Index

**New notes (CREATE):** one Write call per file to `<VAULT_PATH>/<PROJECT_NAME>/<kebab-title>.md`.

Note format:
```markdown
---
title: "[Titolo conciso — l'idea, non il file]"
category: algoritmo | pattern-architetturale | hack | conoscenza-di-dominio | decisione | frammento
project: PROJECT_NAME
source: relative/path/to/file.ext
tags: [tag1, tag2, tag3]
date: YYYY-MM-DD
updated:
---

**Descrizione:** [1–3 frasi autocontenute.]

**Perché non-ovvio:** [Alternativa default e perché questa è diversa.]

**Ricostruzione:**
[Pseudocodice ≤8 righe, o ometti se la descrizione basta.]
```

**Extended notes (EXTEND):** Edit existing file to append:
```markdown

## Integrazione (YYYY-MM-DD)
[Solo le informazioni nuove trovate in questa passata.]
```
Also update frontmatter `updated: YYYY-MM-DD`.

**Project index** — Write/overwrite `<VAULT_PATH>/_index/<PROJECT_NAME>.md`:
```markdown
---
project: PROJECT_NAME
source_path: ROOT
status: wip
first_distilled: YYYY-MM-DD
updated: YYYY-MM-DD
passes: N
concepts: N_TOTAL
---

# PROJECT_NAME

| Concetto | Categoria | Tags | Aggiornato |
|----------|-----------|------|------------|
| [[percorso\|Titolo]] | categoria | tag1, tag2 | data |

## Query Dataview
\```dataview
TABLE category, tags, updated
FROM "PROJECT_NAME"
SORT category ASC
\```

## Note di passata
- **Passata N (YYYY-MM-DD):** N nuovi concetti, N estesi, N saltati
```

**Console output:**
```
/distill completato — PROJECT_NAME (passata N)
Vault: <VAULT_PATH>/<PROJECT_NAME>/

  Nuovi:    N  (creati)
  Estesi:   N  (integrati)
  Saltati:  N  (già documentati)
  Totale vault: N concetti

Prossimo passo: apri Obsidian → _index/PROJECT_NAME
Quando sei soddisfatto → aggiorna status: review in Obsidian
```

---

## Pipeline Status (Obsidian)

The `_index/<PROJECT_NAME>.md` file tracks pipeline state via its `status` property:

| Status | Significato | Chi lo imposta |
|--------|-------------|----------------|
| `queue` | da processare | tu, manualmente |
| `wip` | distillazione in corso | skill (automatico) |
| `review` | distillato, verifica umana | tu, dopo ogni passata |
| `done` | verificato, sicuro da eliminare | tu, decisione finale |

Dataview query per vedere il pipeline completo:
```dataview
TABLE status, passes, concepts, updated
FROM "_index"
SORT status ASC
```

---

## Absolute Rules

1. **Titoli sono idee, non file.** Mai il nome del file come titolo.
2. **Ogni nota è autocontenuta** — comprensibile senza il codice originale.
3. **Niente di ovvio.** Se ci si arriva in 5 minuti, non va nel vault.
4. **Nessun limite numerico.** Estrai tutto ciò che è non-ovvio.
5. **Mai sovrascrivere note esistenti.** Solo CREATE o EXTEND, mai replace.
6. **Prosa prima, codice solo se necessario** (≤8 righe).
7. **Nessuna domanda a metà.**
8. **Il vault deve sopravvivere alla cancellazione del progetto.**
