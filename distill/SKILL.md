---
name: distill
description: Extract and document all unique ideas, algorithms, patterns, and non-obvious
  knowledge from a project into atomic knowledge notes. Unlike /preserve (which saves
  files), /distill saves concepts — the reasoning, decisions, and insights that cannot
  be reconstructed from scratch. Each concept becomes a separate markdown file with
  YAML frontmatter (novelty 1-3, see_also links), stored flat in a notes/ folder
  inside the vault, compatible with Obsidian + Dataview. Supports multiple passes —
  on re-run, extends existing notes rather than overwriting. Use when you want to
  "extract ideas before deleting a project", "document what I learned from this codebase",
  "capture unique knowledge", "distill project insights", or "build a knowledge base"
  from existing code.
version: 5.0.0
context: fork
agent: general-purpose
allowed-tools: Read, Grep, Glob, Bash, Write
argument-hint: [path] [output-vault]
---

You are running the **distill** skill. Read every file in a project, extract every non-obvious concept, and write one markdown file per concept to a central knowledge vault — compatible with Obsidian + Dataview.

**Core principle:** files are reconstructable, ideas are not. Each note must be self-contained: a competent developer with no access to the original code must be able to understand and re-implement the concept from the note alone.

**Multiple passes:** designed to run multiple times on the same project. Each run reads existing vault notes first and only adds or extends — never overwrites.

**Vault layout:**
```
<VAULT_PATH>/
  notes/          ← all concept notes, flat (no per-project subfolders)
  _index/         ← one file per project, pipeline tracking only
```

The skill creates only `notes/` and `_index/`. Any other folders (views, dashboards, queries) are managed entirely by the user.

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
mkdir -p "<VAULT_PATH>/notes"
mkdir -p "<VAULT_PATH>/_index"
```

**Load existing notes** — read every `.md` in `<VAULT_PATH>/notes/`:
```bash
ls "<VAULT_PATH>/notes/" 2>/dev/null
```
For each file, read it and extract:
- `title` from frontmatter + first 2 lines of body → add to `KNOWN_NOTES` map (filename → {title, summary})
- `pass` → find highest pass number for this project (`project = PROJECT_NAME`) → `LAST_PASS`

`CURRENT_PASS = LAST_PASS + 1` (or `1` if no existing notes for this project).

Print: `Passata N | Note vault esistenti: N totali (di cui N di PROJECT_NAME) | Vault: VAULT_PATH`

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
grep -rl "Math\.\(sin\|cos\|sqrt\|pow\|log\)\|sigmoid\|entropy" "<ROOT>" -i 2>/dev/null
```

Files matching multiple signals → read first.

---

## Phase 4 — Read & Extract Concepts

For each file, ask: **"Would a competent developer say 'obvious' or 'interesting — I wouldn't have thought of that'?"**

If *interesting* → extract and assign novelty. If *obvious* → skip.

### Novelty scale (1–3)

| Score | Calibration |
|-------|-------------|
| `1` | Interessante: non-standard ma derivabile — un esperto ci arriva da solo con un po' di tempo |
| `2` | Non-ovvio: richiede esperienza specifica, conoscenza di dominio, o un insight creativo |
| `3` | Raro: difficile da riscoprire indipendentemente; improbabile senza aver affrontato esattamente questo problema |

When uncertain between two scores, assign the lower. Never assign novelty 1 to something truly obvious — the minimum for extraction is already "not obvious."

### Categories

| `category` | What qualifies |
|------------|---------------|
| `algoritmo` | Non-standard computation, custom data structure, formula from scratch, unexpected optimization |
| `pattern-architetturale` | Unusual component communication, inverted data flow, non-standard layering |
| `hack` | Workaround for platform/library limitation, non-obvious sequencing, polyfill |
| `conoscenza-di-dominio` | Business rules, thresholds, ratios encoding hard-won domain expertise |
| `decisione` | Why something non-standard was chosen — when the default would seem simpler |
| `frammento` | Code so short and dense that quoting it is the most efficient representation (≤8 lines) |

### Not worth extracting
Standard CRUD, libraries used as intended, boilerplate, self-evident config, standard patterns used standardly, anything a competent developer arrives at in <5 minutes.

### See-also detection
While extracting, note if a concept seems related to an already-known note (from `KNOWN_NOTES`). If yes, record the relationship for the `see_also` field.

Also check: does this concept appear in notes from *other projects* in `KNOWN_NOTES`? If the same idea exists elsewhere with a different `project`, add a cross-project `see_also` link — this is the most valuable connection the vault can surface.

### Per-concept deduplication

**Case A — New concept:** create new file. Action: `CREATE`.

**Case B — Existing concept (same project), no new info:** skip. Action: `SKIP`.

**Case C — Existing concept (same project), new details found:** append `## Integrazione (YYYY-MM-DD)` to existing file, update `updated` and raise `novelty` if justified. Action: `EXTEND`.

**Case D — Same concept, different project:** create new file with different `project`. Add `see_also:` linking to the other project's version. Action: `CREATE`.

---

## Phase 5 — Native Files

View each NATIVE file with Read tool. Extract a note only if the file contains original creative work with non-obvious choices. Generic images, icons, screenshots: no note.

---

## Phase 6 — Deduplication Pass

After extracting all concepts: if two newly-extracted concepts describe the same idea → merge into one, `source` lists both files.

---

## Phase 7 — Decide Actions

Classify each note: `CREATE` / `EXTEND` / `SKIP`. Count each.

---

## Phase 8 — Write Files & Update Index

**Filename:** `<concept-slug>-<project-slug>.md` (kebab-case, max 80 chars total). This prevents collisions when the same concept name appears in two projects.

**New notes (CREATE):** one Write call per file to `<VAULT_PATH>/notes/<filename>.md`:

```markdown
---
title: "[Titolo conciso — l'idea, non il file]"
category: algoritmo | pattern-architetturale | hack | conoscenza-di-dominio | decisione | frammento
novelty: 1-3
project: PROJECT_NAME
source: relative/path/to/file.ext
tags: [tag1, tag2, tag3]
see_also: []
date: YYYY-MM-DD
updated:
pass: CURRENT_PASS
---

**Descrizione:** [1–3 frasi autocontenute.]

**Perché non-ovvio:** [Alternativa default e perché questa è diversa.]

**Ricostruzione:**
[Pseudocodice ≤8 righe, o ometti se la descrizione basta.]

**Quando riapplicare:** [Una frase: in quale scenario futuro questa soluzione torna utile. Ometti per `frammento` e `conoscenza-di-dominio`.]
```

**Extended notes (EXTEND):** append to existing file:
```markdown

## Integrazione (YYYY-MM-DD) — passata CURRENT_PASS
[Solo le informazioni nuove.]
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

## Storico passate
| Passata | Data | Nuovi | Estesi | Saltati |
|---------|------|-------|--------|---------|
| 1 | YYYY-MM-DD | N | N | N |

## Concetti estratti
| Concetto | Categoria | Novelty |
|----------|-----------|---------|
| [[notes/filename\|Titolo]] | categoria | 2 |

## Dataview — solo questo progetto
\```dataview
TABLE category, novelty, tags
FROM "notes"
WHERE project = "PROJECT_NAME"
SORT novelty DESC
\```
```

**Console output:**
```
/distill completato — PROJECT_NAME (passata CURRENT_PASS)
Vault: VAULT_PATH/notes/

  Nuovi:    N
  Estesi:   N
  Saltati:  N
  Totale vault (tutti i progetti): N concetti

  Novelty:  ★★★ N  |  ★★ N  |  ★ N

Prossimo passo → apri Obsidian, views/Dashboard
Quando sei soddisfatto → imposta status: review in _index/PROJECT_NAME
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
6. **Novelty è onesta.** Il 3 deve essere davvero raro.
7. **Prosa prima, codice solo se necessario** (≤8 righe).
8. **Nessuna domanda a metà.**
9. **Il vault deve sopravvivere alla cancellazione del progetto.**
