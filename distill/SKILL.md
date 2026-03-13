---
name: distill
description: Extract and document all unique ideas, algorithms, patterns, and non-obvious
  knowledge from a project into atomic knowledge notes. Unlike /preserve (which saves
  files), /distill saves concepts — the reasoning, decisions, and insights that cannot
  be reconstructed from scratch. Each concept becomes a separate markdown file with
  YAML frontmatter (including a novelty score 1-5), compatible with Obsidian + Dataview
  for search, filtering, and sorting by non-obviousness. Supports multiple passes —
  on re-run, extends existing notes rather than overwriting. Use when you want to
  "extract ideas before deleting a project", "document what I learned from this codebase",
  "capture unique knowledge", "distill project insights", or "build a knowledge base"
  from existing code.
version: 4.0.0
context: fork
agent: general-purpose
allowed-tools: Read, Grep, Glob, Bash, Write
argument-hint: [path] [output-vault]
---

You are running the **distill** skill. Read every file in a project, extract every non-obvious concept, and write one markdown file per concept to a central knowledge vault — compatible with Obsidian + Dataview.

**Core principle:** files are reconstructable, ideas are not. Each note must be self-contained: a competent developer with no access to the original code must be able to understand and re-implement the concept from the note alone.

**Multiple passes:** designed to run multiple times on the same project. Each run reads existing vault notes first and only adds or extends — never overwrites.

**Vault creation:** the skill creates the vault directory automatically. The user does not need to create anything manually — just open Obsidian and point it to the vault folder after the first run.

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

**Load existing notes** — read every `.md` in `<VAULT_PATH>/<PROJECT_NAME>/`:
```bash
ls "<VAULT_PATH>/<PROJECT_NAME>/" 2>/dev/null
```
For each existing file, read it and extract:
- `title` from frontmatter → add to `KNOWN_TITLES` set
- `pass` from frontmatter → find the highest pass number → store as `LAST_PASS`
- Full body → add to `KNOWN_NOTES` map (filename → content)

Current pass number: `CURRENT_PASS = LAST_PASS + 1` (or `1` if no existing notes).

**Read existing index** if `<VAULT_PATH>/_index/<PROJECT_NAME>.md` exists:
- Extract `passes` count and `concepts` count for the summary
- Update `status: wip` (write this single field update)

Print: `Passata N | Note esistenti: N | Progetto: PROJECT_NAME | Vault: VAULT_PATH`

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

If *interesting* → extract and assign a `novelty` score. If *obvious* → skip entirely.

### Novelty score (assign to every extracted concept)

| Score | Calibration |
|-------|-------------|
| `1` | Non-standard ma derivabile: un esperto ci arriva da solo in un'ora |
| `2` | Richiede esperienza specifica o conoscenza del dominio per arrivarci |
| `3` | Soluzione creativa non ovvia anche con esperienza; richiede insight |
| `4` | Rara combinazione di vincoli e insight difficile da riscoprire indipendentemente |
| `5` | Eccezionale: improbabile da riscoprire senza aver affrontato esattamente questo problema |

When in doubt between two scores, assign the lower one. Never assign novelty 1 to anything you would have extracted anyway as "obvious" — if it's worth a note, it's at least 1.

### Categories

| `category` | What qualifies |
|------------|---------------|
| `algoritmo` | Non-standard computation, custom data structure, formula from scratch, unexpected optimization |
| `pattern-architetturale` | Unusual component communication, inverted data flow, non-standard layering |
| `hack` | Workaround for platform/library limitation, non-obvious sequencing, polyfill |
| `conoscenza-di-dominio` | Business rules, thresholds, ratios that encode hard-won domain expertise |
| `decisione` | Why something non-standard was chosen — especially when the default seems simpler |
| `frammento` | Code so short and dense that quoting it is the most efficient representation (≤8 lines) |

### Not worth extracting
Standard CRUD, libraries used as intended, boilerplate, self-evident config, standard patterns used standardly, anything a competent developer arrives at in <5 minutes.

### Per-concept deduplication

Compare each extracted concept against `KNOWN_TITLES` and `KNOWN_NOTES`:

**Case A — New concept** (title not in KNOWN_TITLES): create new file. Action: `CREATE`.

**Case B — Existing concept, no new information**: skip. Action: `SKIP`.

**Case C — Existing concept, new details found** (new context, edge case, correction, additional example): append `## Integrazione (YYYY-MM-DD)` to existing file + update `updated` and `novelty` (raise if new details justify it) in frontmatter. Action: `EXTEND`.

**Case D — Same concept, different project**: create new file with different `project`. Action: `CREATE`.

---

## Phase 5 — Native Files

View each NATIVE file with the Read tool. Extract a note only if the file contains original creative work with non-obvious choices. Generic images, icons, screenshots: no note.

---

## Phase 6 — Deduplication Pass

After extracting all concepts: if two newly-extracted concepts describe the same idea → merge into one, list both source files in `source`.

---

## Phase 7 — Decide Actions

Classify each note: `CREATE` / `EXTEND` / `SKIP`. Count each.

---

## Phase 8 — Write Files & Update Index

**New notes (CREATE):** one Write call per file to `<VAULT_PATH>/<PROJECT_NAME>/<kebab-title>.md`:

```markdown
---
title: "[Titolo conciso — l'idea, non il file]"
category: algoritmo | pattern-architetturale | hack | conoscenza-di-dominio | decisione | frammento
novelty: 1-5
project: PROJECT_NAME
source: relative/path/to/file.ext
tags: [tag1, tag2, tag3]
date: YYYY-MM-DD
updated:
pass: CURRENT_PASS
---

**Descrizione:** [1–3 frasi autocontenute.]

**Perché non-ovvio:** [Alternativa default e perché questa è diversa.]

**Ricostruzione:**
[Pseudocodice ≤8 righe, o ometti se la descrizione basta.]
```

**Extended notes (EXTEND):** append to existing file:
```markdown

## Integrazione (YYYY-MM-DD) — passata CURRENT_PASS
[Solo le informazioni nuove trovate in questa passata.]
```
Update frontmatter: `updated: YYYY-MM-DD`. Raise `novelty` if justified.

**Project index** — Write `<VAULT_PATH>/_index/<PROJECT_NAME>.md`:

```markdown
---
project: PROJECT_NAME
source_path: ROOT
status: wip
first_distilled: YYYY-MM-DD
updated: YYYY-MM-DD
passes: CURRENT_PASS
concepts: N_TOTAL
---

# PROJECT_NAME

| Concetto | Categoria | Novelty | Tags | Passata |
|----------|-----------|---------|------|---------|
| [[percorso\|Titolo]] | categoria | ⭐⭐⭐ | tag1 | 1 |

## Storico passate
| Passata | Data | Nuovi | Estesi | Saltati |
|---------|------|-------|--------|---------|
| 1 | YYYY-MM-DD | N | N | N |
| 2 | YYYY-MM-DD | N | N | N |

## Query Dataview utili

Tutti i concetti ordinati per novelty:
\```dataview
TABLE category, novelty, tags, pass
FROM "PROJECT_NAME"
SORT novelty DESC
\```

Solo i più rari (novelty ≥ 4):
\```dataview
TABLE category, project, tags
FROM "PROJECT_NAME"
WHERE novelty >= 4
SORT novelty DESC
\```
```

**Console output:**
```
/distill completato — PROJECT_NAME (passata CURRENT_PASS)
Vault: <VAULT_PATH>/<PROJECT_NAME>/

  Nuovi:    N  (creati)
  Estesi:   N  (integrati)
  Saltati:  N  (già documentati)
  Totale vault: N concetti

  Per novelty:  ⭐⭐⭐⭐⭐ N  |  ⭐⭐⭐⭐ N  |  ⭐⭐⭐ N  |  ⭐⭐ N  |  ⭐ N

Stato pipeline: wip → imposta "review" in Obsidian quando sei soddisfatto
```

---

## Obsidian setup (prima volta)

Il vault viene creato automaticamente dalla skill. Per aprirlo:
1. Apri Obsidian → "Open folder as vault" → seleziona `<VAULT_PATH>`
2. Installa il plugin **Dataview**: Settings → Community Plugins → Browse → "Dataview"
3. Crea una nota `Dashboard.md` con:

```dataview
TABLE status, passes, concepts, updated
FROM "_index"
SORT status ASC
```

---

## Pipeline status

Tracciato nel frontmatter di `_index/<PROJECT_NAME>.md`:

| Status | Significato | Chi lo imposta |
|--------|-------------|----------------|
| `queue` | da processare | tu (manuale) |
| `wip` | distillazione in corso | skill (auto) |
| `review` | da verificare | tu (dopo ogni passata) |
| `done` | verificato, sicuro da eliminare | tu (decisione finale) |

---

## Absolute Rules

1. **Titoli sono idee, non file.**
2. **Ogni nota è autocontenuta** — comprensibile senza il codice originale.
3. **Niente di ovvio.** Novelty minima: 1. Se è meno di 1, non estrarre.
4. **Nessun limite numerico.** Estrai tutto ciò che è non-ovvio.
5. **Mai sovrascrivere note esistenti.** Solo CREATE o EXTEND.
6. **Novelty è onesta.** Non gonfiare i punteggi — il 5 deve essere davvero eccezionale.
7. **Prosa prima, codice solo se necessario** (≤8 righe).
8. **Nessuna domanda a metà.**
9. **Il vault deve sopravvivere alla cancellazione del progetto.**
