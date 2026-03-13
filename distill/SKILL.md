---
name: distill
description: Extract and document all unique ideas, algorithms, patterns, and non-obvious
  knowledge from a project into atomic knowledge notes. Unlike /preserve (which saves
  files), /distill saves concepts — the reasoning, decisions, and insights that cannot
  be reconstructed from scratch. Each concept becomes a separate markdown file with
  YAML frontmatter, compatible with Obsidian + Dataview for search and filtering.
  Use when you want to "extract ideas before deleting a project", "document what I
  learned from this codebase", "capture unique knowledge", "distill project insights",
  or "build a knowledge base" from existing code.
version: 2.0.0
context: fork
agent: general-purpose
allowed-tools: Read, Grep, Glob, Bash, Write
argument-hint: [path] [output-vault]
---

You are running the **distill** skill. Read every file in a project, extract every non-obvious concept, and produce one markdown file per concept inside a central knowledge vault — compatible with Obsidian + Dataview for search, filtering, and linking.

**Core principle:** files are reconstructable, ideas are not. Your output is not a report about files — it is a collection of atomic knowledge notes. Each note must be self-contained: a competent developer with no access to the original code must be able to understand and re-implement the concept from the note alone.

Work through all 7 phases autonomously. Never ask clarifying questions.

**If context pressure forces abbreviation**, write whatever notes you have extracted so far, then write the index. Never skip Phase 1 or 7.

---

## Phase 1 — Setup

Parse `$ARGUMENTS`:
- First token (if present): `SOURCE_PATH` — project to distill. Default: `.`
- Second token (if present): `VAULT_PATH` — output knowledge vault. Default: `~/knowledge`

```bash
cd "<SOURCE_PATH>" && pwd   # → ROOT
basename "<ROOT>"           # → PROJECT_NAME (used in all note frontmatter)
mkdir -p "<VAULT_PATH>"     # ensure vault exists
```

If SOURCE_PATH invalid: stop and tell the user.

**Vault structure:**
```
<VAULT_PATH>/
  <PROJECT_NAME>/         ← one subfolder per project
    concept-name.md       ← one file per concept
    ...
  _index/
    <PROJECT_NAME>.md     ← project summary and concept list
```

**Check for existing notes:** `ls "<VAULT_PATH>/<PROJECT_NAME>/" 2>/dev/null` — if files exist, read their titles to avoid duplicating already-extracted concepts.

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
- **SKIP:** lock files, minified (`*.min.js *.min.css`), source maps (`*.map`), empty files, auto-generated (first 8 lines contain `THIS FILE IS AUTO-GENERATED` / `DO NOT EDIT` / `@generated`), licenses (`LICENSE* COPYING*`), fonts (`.ttf .otf .woff .woff2`), compiled objects (`.o .pyc .class`)
- **NATIVE:** `.pdf .jpg .jpeg .png .webp .gif` — read with Read tool
- **Unknown extension:** `head -c 512 "<path>" 2>/dev/null | LC_ALL=C grep -cP '\x00'` → 0 = TEXT, >0 = SKIP
- **TEXT:** everything else

Print: `Sorgente: ROOT | Da leggere: N_TEXT testo + N_NATIVE immagini/PDF | Saltati: N_SKIP`

---

## Phase 3 — Priority Pre-Scan

Run these Grep searches to identify high-signal files. Read them first so context pressure doesn't cut off the most valuable content.

```bash
grep -rl "HACK:\|WORKAROUND:\|monkey.patch\|kludge" "<ROOT>" 2>/dev/null
grep -rl "algorithm\|heuristic\|approximat\|theorem\|invariant" "<ROOT>" -i 2>/dev/null
grep -rl "EXPERIMENTAL\|POC\|WIP\|DRAFT\|SPIKE" "<ROOT>" -i 2>/dev/null
grep -rl "eval\|Function(\|__import__\|ctypes\|FFI\|unsafe" "<ROOT>" 2>/dev/null
grep -rl "Math\.\(random\|sin\|cos\|sqrt\|pow\|log\)\|sigmoid\|entropy" "<ROOT>" -i 2>/dev/null
```

Build reading order: files matching multiple signals → first. Files matching none → last.

---

## Phase 4 — Read & Extract Concepts

Read files in priority order. For each file, apply the extraction filter:

> **"Would a competent developer, given only a description of this solution, say 'obvious' or 'interesting — I wouldn't have thought of that'?"**

*Interesting* → extract a note. *Obvious* → move on.

### What to extract

| Category (`category` in frontmatter) | What qualifies |
|---------------------------------------|---------------|
| `algoritmo` | Non-standard computation, custom data structure, formula implemented from scratch, unexpected optimization |
| `pattern-architetturale` | Unusual component communication, inverted data flow, server emitting code to client, non-standard layering |
| `hack` | Workaround for platform/library limitation, non-obvious sequencing, polyfill for missing behavior |
| `conoscenza-di-dominio` | Business rules, thresholds, ratios embedded in logic that encode hard-won domain expertise |
| `decisione` | Why something non-standard was chosen — especially when the default would seem simpler |
| `frammento` | Code so short and dense that quoting it directly is the most efficient representation (≤8 lines) |

### What NOT to extract
- Standard CRUD (fetch, save, delete)
- Libraries used in their intended way
- Boilerplate (React scaffold, Express route, Drupal hook stub)
- Config with self-evident values (`port: 3000`)
- Standard design patterns used standardly
- Anything a competent developer arrives at in <5 minutes

### Concept note format

Each concept = one file. Filename: `kebab-case-title.md` (no special chars, max 60 chars).

```markdown
---
title: "[Titolo conciso — l'idea, non il file]"
category: algoritmo | pattern-architetturale | hack | conoscenza-di-dominio | decisione | frammento
project: PROJECT_NAME
source: relative/path/to/file.ext
tags: [tag1, tag2, tag3]
date: YYYY-MM-DD
---

**Descrizione:** [1–3 frasi che spiegano l'idea compiutamente. Chi non ha visto il codice deve capire.]

**Perché non-ovvio:** [Qual è l'alternativa default che non hai usato, e perché questa soluzione è diversa/migliore.]

**Ricostruzione:**
[Pseudocodice ≤8 righe, O descrizione algoritmica, O ometti se la descrizione basta.]
```

**Shortform** (for simple but non-obvious ideas):
```markdown
---
title: "..."
category: ...
project: PROJECT_NAME
source: relative/path
tags: [...]
date: YYYY-MM-DD
---
[Una frase autocontenuta. Perché non-ovvio: ...]
```

### Rules for notes
- **Titolo = idea, non file.** "Parallel eval-fetch bootstrap", non "js/script.js"
- **Autocontenuto.** Chi non ha il codice deve capire.
- **Una nota per concetto.** Se lo stesso pattern appare in 3 file, una nota con `source` che lista tutti e tre: `source: [file1, file2, file3]`
- **Prosa prima, codice solo se necessario.** Snippet ≤8 righe.
- **Scrivi in italiano.** Il codice resta nella lingua originale.
- **Tag utili:** linguaggio (`javascript`, `php`, `rust`, `css`), dominio (`gioco`, `drupal`, `auth`, `ui`), tecnica (`eval`, `websocket`, `css-animation`, `sql`)

---

## Phase 5 — Native Files

View each NATIVE file with the Read tool. Extract a note only if the file contains original creative work with non-obvious choices (game map with specific parameters, diagram with non-derivable knowledge, design system with non-trivial rationale). Generic stock images, icons, screenshots: no note.

---

## Phase 6 — Deduplication

Before writing, review all notes mentally:
- Same underlying idea in multiple notes → merge, update `source` to list all files
- Title clash with existing vault notes → append `-(2)` or merge if truly identical

---

## Phase 7 — Write All Files

**One Write call per concept note** to `<VAULT_PATH>/<PROJECT_NAME>/<filename>.md`.

Then write the **project index** — one Write call to `<VAULT_PATH>/_index/<PROJECT_NAME>.md`:

```markdown
---
project: PROJECT_NAME
source_path: ROOT
distilled: YYYY-MM-DD
concepts: N
---

# PROJECT_NAME — Indice Concetti

| Concetto | Categoria | Tag |
|----------|-----------|-----|
| [[concept-file\|Titolo]] | categoria | tag1, tag2 |
...

## Dataview query (incolla in Obsidian)
\```dataview
TABLE category, tags, source
FROM "PROJECT_NAME"
SORT category ASC
\```
```

Finally print to console:
```
/distill completato.
Vault: <VAULT_PATH>/<PROJECT_NAME>/
Concetti estratti: N
  algoritmo: N
  pattern-architetturale: N
  hack: N
  conoscenza-di-dominio: N
  decisione: N
  frammento: N
File originali analizzati: N_TEXT + N_NATIVE
```

---

## Absolute Rules

1. **Titoli sono idee, non file.**
2. **Ogni nota è autocontenuta** — comprensibile senza il codice originale.
3. **Niente di ovvio.** Se ci si arriva in 5 minuti, non va nella knowledge base.
4. **Nessun limite numerico.** Estrai tutto ciò che è non-ovvio.
5. **Prosa prima, codice solo se necessario** e ≤8 righe.
6. **Una Write per file.** Tanti Write call quante note + 1 per l'indice.
7. **Nessuna domanda a metà.**
8. **Il vault deve sopravvivere alla cancellazione del progetto.** Ogni nota deve essere comprensibile senza il sorgente.
