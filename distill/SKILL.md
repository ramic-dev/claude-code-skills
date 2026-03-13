---
name: distill
description: Extract and document all unique ideas, algorithms, patterns, and non-obvious
  knowledge from a project into atomic knowledge notes. Unlike /preserve (which saves
  files), /distill saves concepts — the reasoning, decisions, and insights that cannot
  be reconstructed from scratch. Each concept becomes a separate markdown file with
  YAML frontmatter (novelty 1-3, found_in as tag list, see_also links), stored flat
  in a notes/ folder inside the vault, compatible with Obsidian + Dataview. Supports
  multiple passes and cross-project deduplication: if the same concept appears in two
  projects, one canonical note grows with found_in rather than duplicating.
version: 7.0.0
context: fork
agent: general-purpose
allowed-tools: Read, Grep, Glob, Bash, Write
argument-hint: [path] [output-vault]
---

You are running the **distill** skill. Read every file in a project, extract every non-obvious concept, and write one markdown file per concept to a central knowledge vault — compatible with Obsidian + Dataview.

**Core principle:** files are reconstructable, ideas are not. Each note must be self-contained: a competent developer with no access to the original code must be able to understand and re-implement the concept from the note alone.

**Deduplication model:** notes are canonical and cross-project. If the same concept appears in multiple projects, one note exists with `found_in: [project1, project2]` growing over time. There are no per-project duplicate notes.

**Multiple passes:** designed to run multiple times on the same or different projects. Each run reads existing vault notes first and only adds or extends — never overwrites.

**Vault layout:**
```
<VAULT_PATH>/
  notes/      ← all concept notes, flat, canonical (one per concept across all projects)
  _index/     ← one file per project, pipeline tracking only
```

The skill creates only `notes/` and `_index/`. Everything else is managed by the user.

Work through all 8 phases autonomously. Never ask clarifying questions.

**If context pressure forces abbreviation**, write notes extracted so far, then the index. Never skip Phase 1 or 8.

---

## Phase 1 — Setup & Existing Knowledge Load

Parse `$ARGUMENTS`:
- First token (if present): `SOURCE_PATH` — project to distill. Default: `.`
- Second token (if present): `VAULT_PATH` — output vault. Default: `~/knowledge`

```bash
cd "<SOURCE_PATH>" && pwd     # → ROOT
basename "<ROOT>"             # → PROJECT_NAME
mkdir -p "<VAULT_PATH>/notes"
mkdir -p "<VAULT_PATH>/_index"
```

**Load existing notes** — read every `.md` in `<VAULT_PATH>/notes/`:
```bash
ls "<VAULT_PATH>/notes/" 2>/dev/null
```
For each file, read it and extract:
- `title` from frontmatter + first 2 lines of body → add to `KNOWN_NOTES` map (filename → {title, summary, found_in, tags})
- Find notes where `found_in` contains `PROJECT_NAME` → determine `LAST_PASS` from their `pass` field

`CURRENT_PASS = LAST_PASS + 1` (or `1` if no existing notes mention this project).

Print: `Passata N | Note vault totali: N | Già da questo progetto: N | Vault: VAULT_PATH`

---

## Phase 2 — File Discovery & Partition

```bash
find "<ROOT>" -type f \
  ! -path "*/.git/*" \
  ! -path "*/node_modules/*" ! -path "*/__pycache__/*" \
  ! -path "*/dist/*" ! -path "*/build/*" \
  ! -path "*/vendor/*" ! -path "*/web/vendor/*" \
  ! -path "*/.next/*" ! -path "*/.venv/*" ! -path "*/venv/*" \
  ! -path "*/target/*" ! -path "*/.gradle/*" ! -path "*/coverage/*" \
  ! -path "*/core/*" ! -path "*/web/core/*" \
  ! -path "*/modules/contrib/*" ! -path "*/themes/contrib/*" \
  ! -path "*/profiles/contrib/*" \
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

Read these files first — highest knowledge density, regardless of other signals:
```bash
find "<ROOT>" -type f \( \
  -iname "README*" -o -iname "ARCHITECTURE*" -o -iname "DESIGN*" \
  -o -iname "DECISIONS*" -o -iname "ADR*" -o -iname "CHANGELOG*" \
  -o -path "*/docs/*" -o -path "*/doc/*" -o -path "*/decisions/*" \
\) ! -path "*/.git/*" ! -path "*/node_modules/*" ! -path "*/vendor/*" \
   ! -path "*/core/*" ! -path "*/web/core/*" \
   ! -path "*/modules/contrib/*" ! -path "*/themes/contrib/*" \
   2>/dev/null
```

Then scan for high-signal code patterns (apply same exclusions):
```bash
grep -rl "HACK:\|WORKAROUND:\|monkey.patch\|kludge" "<ROOT>" \
  --exclude-dir=".git" --exclude-dir="node_modules" --exclude-dir="vendor" \
  --exclude-dir="core" --exclude-dir="modules/contrib" --exclude-dir="themes/contrib" \
  2>/dev/null
grep -rl "algorithm\|heuristic\|approximat\|theorem\|invariant" "<ROOT>" -i \
  --exclude-dir=".git" --exclude-dir="node_modules" --exclude-dir="vendor" \
  --exclude-dir="core" --exclude-dir="modules/contrib" --exclude-dir="themes/contrib" \
  2>/dev/null
grep -rl "EXPERIMENTAL\|POC\|WIP\|DRAFT\|SPIKE" "<ROOT>" -i \
  --exclude-dir=".git" --exclude-dir="node_modules" --exclude-dir="vendor" \
  --exclude-dir="core" 2>/dev/null
grep -rl "eval\|Function(\|__import__\|ctypes\|FFI\|unsafe" "<ROOT>" \
  --exclude-dir=".git" --exclude-dir="node_modules" --exclude-dir="vendor" \
  --exclude-dir="core" 2>/dev/null
grep -rl "Math\.\(sin\|cos\|sqrt\|pow\|log\)\|sigmoid\|entropy" "<ROOT>" -i \
  --exclude-dir=".git" --exclude-dir="node_modules" --exclude-dir="vendor" \
  --exclude-dir="core" 2>/dev/null
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

When uncertain between two scores, assign the lower.

### Categories

| `category` | What qualifies |
|------------|---------------|
| `algoritmo` | Non-standard computation, custom data structure, formula from scratch, unexpected optimization |
| `pattern-architetturale` | Unusual component communication, inverted data flow, non-standard layering |
| `hack` | Workaround for platform/library limitation, non-obvious sequencing, polyfill |
| `conoscenza-di-dominio` | Business rules, thresholds, ratios encoding hard-won domain expertise |
| `decisione` | Why something non-standard was chosen — when the default would seem simpler |
| `frammento` | Code so short and dense that quoting it is the most efficient representation (≤8 lines) |

### Tag taxonomy

Tags must be lowercase kebab-case. Use atomic tags, not compound ones:
- Technology: `drupal`, `php`, `javascript`, `python`, `react`, `sql`, `bash`
- Subsystem: `views`, `twig`, `webpack`, `docker`, `nginx`, `cron`
- Concept: `caching`, `auth`, `form-api`, `migrations`, `config-api`, `hooks`
- Domain: `performance`, `security`, `ui`, `api`, `cli`, `testing`

Never: `drupal-views` (split into `drupal` + `views`), CamelCase, project names as concept tags.

### Not worth extracting
Standard CRUD, libraries used as intended, boilerplate, self-evident config, standard patterns used standardly, anything a competent developer arrives at in <5 minutes.

### Per-concept deduplication (cross-project)

Compare each extracted concept against ALL notes in `KNOWN_NOTES` (entire vault, not just this project):

**Case A — Genuinely new concept** (no matching note anywhere in vault):
- Action: `CREATE` — new file, `found_in: [PROJECT_NAME]`

**Case B — Same concept, same project, no new info:**
- Action: `SKIP`

**Case C — Same concept, same project, new details found:**
- Action: `EXTEND` — append `## Integrazione (YYYY-MM-DD)` section, update `updated`, raise `novelty` if justified

**Case D — Same concept found in a different project** (title/description matches existing note from another project):
- Action: `FOUND_IN` — add `PROJECT_NAME` to the existing note's `found_in` array, add current `source` to `source` field, optionally append a one-line context note under `## Visto anche in (PROJECT_NAME)` if the usage context differs meaningfully
- Do NOT create a new file

**Similarity check for Case D:** titles are similar if they describe the same underlying mechanism. Use judgment: "auto-registrazione DisplayExtender via hook_install" and "registrazione automatica plugin via install hook" describe the same thing → Case D.

---

## Phase 5 — Native Files

View each NATIVE file with Read tool. Extract a note only if the file contains original creative work with non-obvious choices. Generic images, icons, screenshots: no note.

---

## Phase 6 — Deduplication Pass

After extracting all concepts: if two newly-extracted concepts describe the same idea → merge into one, listing both sources.

---

## Phase 7 — Decide Actions & Build see_also

Classify each concept: `CREATE` / `EXTEND` / `FOUND_IN` / `SKIP`. Count each.

**For every concept marked CREATE or EXTEND**, build `see_also`:
- Compare the concept's title, category, and tags against all `KNOWN_NOTES`
- If a note in the vault is conceptually related (same domain, complementary mechanism, or prerequisite knowledge) → add its filename to `see_also`
- Also cross-link concepts extracted in this same pass if they are related
- Limit: max 5 entries in `see_also`. If none are relevant, leave `[]`.

---

## Phase 8 — Write Files & Update Index

**Filename:** `<concept-slug>.md` (kebab-case, max 60 chars). No project suffix — notes are canonical across projects.

**New notes (CREATE):** one Write call per file to `<VAULT_PATH>/notes/<filename>.md`:

```markdown
---
title: "[Titolo conciso — l'idea, non il file]"
category: algoritmo | pattern-architetturale | hack | conoscenza-di-dominio | decisione | frammento
novelty: 1-3
found_in: [PROJECT_NAME]
source: relative/path/to/file.ext
tags: [tag1, tag2, project/PROJECT_NAME]
see_also: [related-note.md, other-note.md]
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

**Note:** `tags` must always end with `project/PROJECT_NAME` — this enables native Obsidian tag navigation by project alongside Dataview queries via `found_in`.

**Extended notes (EXTEND):** append to existing file:
```markdown

## Integrazione (YYYY-MM-DD) — passata CURRENT_PASS
[Solo le informazioni nuove.]
```
Update frontmatter: `updated: YYYY-MM-DD`. Raise `novelty` if justified. Add `project/PROJECT_NAME` to `tags` if not already present.

**Cross-project notes (FOUND_IN):** update existing file frontmatter:
- Add `PROJECT_NAME` to `found_in` array
- Add `project/PROJECT_NAME` to `tags` array if not already present
- Add current source path to `source` (make it a list if it was a string)
- Update `updated: YYYY-MM-DD`
- If usage context differs meaningfully, append:
```markdown

## Visto anche in PROJECT_NAME
[Una frase su come viene usato diversamente in questo progetto, se diverso.]
```

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
| Passata | Data | Nuovi | Estesi | Found-in | Saltati |
|---------|------|-------|--------|----------|---------|
| 1 | YYYY-MM-DD | N | N | N | N |

## Concetti di questo progetto
\```dataview
TABLE category, novelty, found_in, tags
FROM "notes"
WHERE contains(found_in, "PROJECT_NAME")
SORT novelty DESC
\```
```

**Console output:**
```
/distill completato — PROJECT_NAME (passata CURRENT_PASS)
Vault: VAULT_PATH/notes/

  Nuovi:      N  (nuovi concetti)
  Estesi:     N  (nuovi dettagli in note esistenti)
  Found-in:   N  (stessa idea già vista in altri progetti)
  Saltati:    N  (già documentati, nulla di nuovo)
  Totale vault: N concetti canonici

  Novelty:  ★★★ N  |  ★★ N  |  ★ N

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
3. **Niente di ovvio.** Novelty minima: 1.
4. **Nessun limite numerico.** Estrai tutto ciò che è non-ovvio.
5. **Mai sovrascrivere note esistenti.** Solo CREATE, EXTEND, o FOUND_IN.
6. **Una nota per concetto, mai due.** Se esiste già → aggiorna `found_in`, non duplicare.
7. **Novelty è onesta.** Il 3 deve essere davvero raro.
8. **Prosa prima, codice solo se necessario** (≤8 righe).
9. **Nessuna domanda a metà.**
10. **Il vault deve sopravvivere alla cancellazione del progetto.**
11. **`tags` include sempre `project/PROJECT_NAME`** — mai omettere, è il ponte tra Dataview e navigazione Obsidian nativa.
12. **I grep di Phase 3 escludono sempre vendor/contrib/core** — mai scansionare codice di terze parti per segnali di priorità.
