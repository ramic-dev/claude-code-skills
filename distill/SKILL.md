---
name: distill
description: Extract and document all unique ideas, algorithms, patterns, and non-obvious
  knowledge from a project into atomic knowledge notes — both technical AND non-technical
  (game design, world-building, design philosophy, creative vision, UX insights, process
  methodology). Unlike /preserve (which saves files), /distill saves concepts — the
  reasoning, decisions, and insights that cannot be reconstructed from scratch. Each
  concept becomes a separate markdown file with YAML frontmatter (novelty/applicability/
  reusability 1-3, composite score 0-10, found_in as tag list, see_also links), stored
  flat in a notes/ folder inside the vault, compatible with Obsidian + Dataview. Supports
  multiple passes and cross-project deduplication: if the same concept appears in two
  projects, one canonical note grows with found_in rather than duplicating.
version: 10.2.0
context: fork
agent: general-purpose
allowed-tools: Read, Grep, Glob, Bash, Write, Edit
argument-hint: [path] [output-vault]
---

You are running the **distill** skill. Read every file in a project, extract every non-obvious concept — both technical AND non-technical — and write one markdown file per concept to a central knowledge vault — compatible with Obsidian + Dataview.

**Core principle:** files are reconstructable, ideas are not. Each note must be self-contained: a competent developer or designer with no access to the original project must be able to understand and re-apply the concept from the note alone. This applies equally to code patterns, game design decisions, narrative structures, creative methodologies, and process insights.

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

**If context pressure forces abbreviation**, write notes extracted so far, then the index. Never skip Phase 1 or 8. In the console output and in the Storico row, mark the pass as incomplete: append `(parziale — N/TOT file letti)` to the row date and print a warning line: `⚠ Passata incompleta: solo N file su TOT processati. Riesegui /distill per continuare.`

---

## Phase 1 — Setup & Existing Knowledge Load

Parse `$ARGUMENTS`:
- First token (if present): `SOURCE_PATH` — project to distill. Default: `.`
- Second token (if present): `VAULT_PATH` — output vault. Default: `~/knowledge`

```bash
cd "<SOURCE_PATH>" && pwd     # → ROOT
basename "<ROOT>"             # → PROJECT_NAME_RAW
mkdir -p "<VAULT_PATH>/notes"
mkdir -p "<VAULT_PATH>/_index"
```

**Normalize PROJECT_NAME** for use as tag and filename:
- Lowercase, replace spaces and special characters with `-`, collapse multiple `-` into one
- Example: `My Project 2024` → `my-project-2024`
- Store as `PROJECT_NAME` (used in frontmatter and filenames)
- Store as `PROJECT_TAG` = `project/PROJECT_NAME` (used in `tags`)

**Load existing index** — if `<VAULT_PATH>/_index/<PROJECT_NAME>.md` exists, read it:
- Extract `first_distilled` date → store as `FIRST_DISTILLED`
- Extract `passes:` value → store as `LAST_PASS` (authoritative source for pass count)
- Extract `status:` value → store as `EXISTING_STATUS`
- Extract all existing rows from the Storico table → store as `STORICO_ROWS`
- If file does not exist: `FIRST_DISTILLED = today`, `LAST_PASS = 0`, `EXISTING_STATUS = none`, `STORICO_ROWS = []`

**Load existing notes** — build `KNOWN_NOTES` from a lightweight grep index (do NOT read every file — too slow and context-heavy):
```bash
# Titles (slug → title)
grep -rh "^title:" "<VAULT_PATH>/notes/" 2>/dev/null

# found_in per note (slug → projects)
grep -rh "^found_in:" "<VAULT_PATH>/notes/" 2>/dev/null

# categories and scores
grep -rhE "^(category|score|novelty|applicability|reusability):" "<VAULT_PATH>/notes/" 2>/dev/null
```
Build `KNOWN_NOTES` map (slug → {title, found_in, category, score}) from grep output alone — without opening individual files. Only open a specific note file if you need to verify a potential FOUND_IN/EXTEND match during Phase 4.

**CRITICAL:** `KNOWN_NOTES` must be complete before Phase 4 begins. Any concept you extract will be checked against it to prevent duplicates. An incomplete KNOWN_NOTES is the primary cause of duplicate notes across sessions.

**Context compression recovery:** if you are resuming after context compression and no longer have the Phase 1 grep results in memory, re-run all three grep commands above before proceeding to Phase 4. Do not rely on remembered note titles — re-run the grep.

`CURRENT_PASS = LAST_PASS + 1`.
`N_VAULT_TOTAL` = total entries in KNOWN_NOTES.
`N_PROJECT_NOTES` = entries in KNOWN_NOTES where `found_in` contains `PROJECT_NAME`.

Print: `Passata N | Note vault totali: N_VAULT_TOTAL | Già da questo progetto: N_PROJECT_NOTES | Vault: VAULT_PATH`

---

## Phase 2 — File Discovery & Partition

```bash
find "<ROOT>" -type f \
  ! -path "*/.git/*" ! -path "*/.claude/*" \
  ! -path "*/node_modules/*" ! -path "*/__pycache__/*" \
  ! -path "*/dist/*" ! -path "*/build/*" \
  ! -path "*/vendor/*" \
  ! -path "*/.next/*" ! -path "*/.venv/*" ! -path "*/venv/*" \
  ! -path "*/target/*" ! -path "*/.gradle/*" ! -path "*/coverage/*" \
  ! -path "*/.godot/*" ! -path "*/.vs/*" \
  ! -path "*/web/core/*" ! -path "*/docroot/core/*" ! -path "*/html/core/*" \
  ! -path "*/web/vendor/*" ! -path "*/docroot/vendor/*" \
  ! -path "*/modules/contrib/*" ! -path "*/themes/contrib/*" \
  ! -path "*/profiles/contrib/*" \
  2>/dev/null | sort
```

**Partition:**
- **SKIP:** lock files, minified (`*.min.js *.min.css`), source maps (`*.map`), empty files, auto-generated (first 8 lines: `THIS FILE IS AUTO-GENERATED` / `DO NOT EDIT` / `@generated`), licenses (`LICENSE* COPYING*`), fonts (`.ttf .otf .woff .woff2`), compiled (`.o .pyc .class`), vector graphics (`.svg`), data files (`.csv .tsv` >10KB, all `.sql` files), binary-embedded XML (`.xlsx .docx .pptx`)
  - Size check: `wc -c < "<path>" 2>/dev/null` → if result >10240 → SKIP
- **NATIVE:** `.pdf .jpg .jpeg .png .webp .gif`
- **Unknown extension:** `head -c 512 "<path>" 2>/dev/null | LC_ALL=C grep -c $'\x00'` → 0 = TEXT, >0 = SKIP (no `-P` flag — macOS BSD grep lacks PCRE)
- **TEXT:** everything else

Print: `Da leggere: N_TEXT testo + N_NATIVE immagini/PDF | Saltati: N_SKIP`

---

## Phase 3 — Priority Pre-Scan

Read these files first — highest knowledge density, regardless of other signals:
```bash
find "<ROOT>" -type f \( \
  -iname "README*" -o -iname "ARCHITECTURE*" -o -iname "DESIGN*" \
  -o -iname "DECISIONS*" -o -iname "ADR*" \
  -o -path "*/docs/*" -o -path "*/doc/*" -o -path "*/decisions/*" \
\) ! -path "*/.git/*" ! -path "*/.claude/*" ! -path "*/node_modules/*" ! -path "*/vendor/*" \
   ! -path "*/.godot/*" ! -path "*/.gradle/*" \
   ! -path "*/web/core/*" ! -path "*/docroot/core/*" \
   ! -path "*/modules/contrib/*" ! -path "*/themes/contrib/*" \
   2>/dev/null || true
```

Then scan for high-signal patterns — both technical and non-technical. Note: `--exclude-dir` matches directory **names**, not paths — use short names:

**Technical signals:**
```bash
grep -rlE "HACK:|WORKAROUND:|monkey.patch|kludge" "<ROOT>" \
  --exclude-dir=".git" --exclude-dir=".claude" --exclude-dir="node_modules" \
  --exclude-dir="vendor" --exclude-dir="contrib" --exclude-dir="core" \
  --exclude-dir=".godot" --exclude-dir=".gradle" \
  2>/dev/null || true
grep -rlEi "algorithm|heuristic|approximat|theorem|invariant" "<ROOT>" \
  --exclude-dir=".git" --exclude-dir=".claude" --exclude-dir="node_modules" \
  --exclude-dir="vendor" --exclude-dir="contrib" --exclude-dir="core" \
  --exclude-dir=".godot" --exclude-dir=".gradle" \
  2>/dev/null || true
grep -rlEi "EXPERIMENTAL|POC|WIP|DRAFT|SPIKE" "<ROOT>" \
  --exclude-dir=".git" --exclude-dir=".claude" --exclude-dir="node_modules" \
  --exclude-dir="vendor" --exclude-dir="contrib" --exclude-dir="core" \
  --exclude-dir=".godot" --exclude-dir=".gradle" \
  2>/dev/null || true
grep -rlE "eval|Function\(|__import__|ctypes|FFI|unsafe" "<ROOT>" \
  --exclude-dir=".git" --exclude-dir=".claude" --exclude-dir="node_modules" \
  --exclude-dir="vendor" --exclude-dir="contrib" --exclude-dir="core" \
  --exclude-dir=".godot" --exclude-dir=".gradle" \
  2>/dev/null || true
grep -rlEi "Math\.(sin|cos|sqrt|pow|log)|sigmoid|entropy" "<ROOT>" \
  --exclude-dir=".git" --exclude-dir=".claude" --exclude-dir="node_modules" \
  --exclude-dir="vendor" --exclude-dir="contrib" --exclude-dir="core" \
  --exclude-dir=".godot" --exclude-dir=".gradle" \
  2>/dev/null || true
```

**Non-technical signals (game design, narrative, creative):**
```bash
# Game design: mechanics, balancing, economy, progression
grep -rlEi "balance|mechanic|progression|economy|reward|difficulty|spawn|loot|cooldown|damage.formula|exp.curve|drop.rate|level.cap" "<ROOT>" \
  --exclude-dir=".git" --exclude-dir=".claude" --exclude-dir="node_modules" \
  --exclude-dir="vendor" --exclude-dir="contrib" --exclude-dir="core" \
  --exclude-dir=".godot" --exclude-dir=".gradle" \
  2>/dev/null || true
# World-building: lore, narrative, mythology, factions
grep -rlEi "lore|mythology|faction|kingdom|cosmolog|backstory|timeline|chronicle|legend" "<ROOT>" \
  --exclude-dir=".git" --exclude-dir=".claude" --exclude-dir="node_modules" \
  --exclude-dir="vendor" --exclude-dir="contrib" --exclude-dir="core" \
  --exclude-dir=".godot" --exclude-dir=".gradle" \
  2>/dev/null || true
# Design decisions and philosophy
grep -rlEi "trade.off|why.not|instead.of|lesson.learned|retrospective|postmortem|decided|chose|rationale" "<ROOT>" \
  --exclude-dir=".git" --exclude-dir=".claude" --exclude-dir="node_modules" \
  --exclude-dir="vendor" --exclude-dir="contrib" --exclude-dir="core" \
  --exclude-dir=".godot" --exclude-dir=".gradle" \
  2>/dev/null || true
```

Also prioritize files with design-heavy extensions or names:
```bash
find "<ROOT>" -type f \( \
  -iname "*.yml" -o -iname "*.yaml" -o -iname "*.json" \
  -o -iname "*design*" -o -iname "*lore*" -o -iname "*balance*" \
  -o -iname "*mechanic*" -o -iname "*rules*" -o -iname "*world*" \
  -o -iname "*creature*" -o -iname "*quest*" -o -iname "*skill*" \
  -o -iname "*item*" -o -iname "*class*" -o -iname "*spell*" \
  -o -iname "CHANGELOG*" -o -iname "HISTORY*" -o -iname "DEVLOG*" \
\) ! -path "*/.git/*" ! -path "*/node_modules/*" ! -path "*/vendor/*" \
   ! -path "*/web/core/*" ! -path "*/modules/contrib/*" \
   2>/dev/null || true
```

Files matching multiple signals → read first.

---

## Phase 4 — Read & Extract Concepts

For each file, ask THREE questions — and treat each independently:

1. **Technical:** "Would a competent developer say 'obvious' or 'interesting — I wouldn't have thought of that'?"
2. **Non-technical (content):** "Is there a game design decision, world-building structure, creative methodology, UX insight, or narrative structure here that encodes hard-won experience?"
3. **Non-technical (meta):** "Does the overall project architecture, constraint philosophy, UX strategy, distribution model, or development process encode a transferable lesson?"

**CRITICAL — anti-technical-bias rule:** After extracting all technical concepts from the project, STOP and do a dedicated non-technical pass. Re-read the project's README and main files asking ONLY questions 2 and 3. Look specifically for:
- **`design-philosophy`**: intentional constraints (e.g. "zero install", "no admin required"), trade-offs with reasoning, why standard approaches were rejected
- **`process`**: development workflows, distribution strategies, update mechanisms as process patterns
- **`ux-interaction`**: adaptive UI that responds to environment (e.g. showing/hiding features based on detected capabilities), progressive disclosure, graceful degradation
- **`creative-vision`**: aesthetic systems, naming conventions with reasoning, user experience goals that shaped technical decisions

A project with 10 technical notes and 0 non-technical notes is almost certainly under-extracted. The ratio should reflect the project's actual knowledge content, not the ease of spotting code patterns.

If *interesting* on any axis → extract and assign scores (novelty, applicability, reusability). If *obvious* on all three → skip.

### Dimensioni del punteggio (tutte su scala 1–3)

| Campo | 1 | 2 | 3 |
|-------|---|---|---|
| `novelty` | Interessante: non-standard ma derivabile — un esperto ci arriva da solo con un po' di tempo. *Es: usare `Date.now()` come ID univoco.* | Non-ovvio: richiede esperienza specifica, conoscenza di dominio, o un insight creativo. *Es: propagazione AC-3 via BFS in WFC, not DFS.* | Raro: difficile da riscoprire indipendentemente; improbabile senza aver affrontato esattamente questo problema. *Es: ticket smuggling via sottoclasse InetSocketAddress per bypassare API Minecraft.* |
| `applicability` | Nicchia/contestuale — funziona solo in questo progetto per ragioni specifiche (es. workaround per un bug di una versione specifica di una libreria). *Es: patch per comportamento rotto di Drupal 9.3.x.* | Dominio-specifico — utile in qualsiasi progetto dello stesso tipo (es. pattern Drupal, ottimizzazione React). *Es: buffered debug log con flush differito in Godot Autoload.* | Cross-dominio — applicabile in qualsiasi progetto software indipendentemente da stack o dominio. *Es: CORS bridge via Chrome extension service worker; JSON extraction da output LLM.* |
| `reusability` | Adattamento pesante — richiede riscrittura significativa per adattarsi a un nuovo contesto (es. hardcoded su struttura dati o API specifica). *Es: algoritmo legato a schema DB proprietario.* | Adattamento leggero — richiede modifiche minori a parametri o nomi (es. sostituire un endpoint, cambiare una soglia). *Es: dead reckoning con costanti di interpolazione da tunare.* | Drop-in — incollabile direttamente in un nuovo progetto senza modifiche o con sole sostituzioni meccaniche di nomi. *Es: `rngFromSeed` (FNV-1a + SFC32); `withLock` via flock su file temp.* |

When uncertain between two scores on **any dimension**, assign the lower. **The `3` level requires a concrete justification you could defend aloud** — if you hesitate, it's a `2`.

**Formula composita (pesi AHP, priorità pratica):**
```
score = round(((novelty-1)*0.45 + (applicability-1)*0.35 + (reusability-1)*0.20) / 2 * 10)
```
- Minimo (1,1,1) → 0 | Medio (2,2,2) → 5 | Massimo (3,3,3) → 10
- `score` è sempre un intero (0–10). Mai scrivere `5.0` o `7.5` — `round()` produce sempre un intero.

### Categories

**Technical categories:**

| `category` | What qualifies |
|------------|---------------|
| `algoritmo` | Non-standard computation, custom data structure, formula from scratch, unexpected optimization |
| `pattern-architetturale` | Unusual component communication, inverted data flow, non-standard layering |
| `hack` | Workaround for platform/library limitation, non-obvious sequencing, polyfill |
| `conoscenza-di-dominio` | Business rules, thresholds, ratios encoding hard-won domain expertise |
| `decisione` | Why something non-standard was chosen — when the default would seem simpler |
| `frammento` | Code so short and dense that quoting it is the most efficient representation (≤8 lines) |

**Non-technical categories:**

| `category` | What qualifies |
|------------|---------------|
| `game-design` | Game mechanics, balancing strategies, economy systems, progression loops, player psychology insights, difficulty curves, reward schedules. Must be a specific design *decision* with reasoning, not just "it's an RPG with levels". |
| `world-building` | Lore systems, cosmologies, faction dynamics, narrative structures, character relationship models, mythology. Must have internal consistency or novel structure, not just flavor text. |
| `design-philosophy` | Intentional trade-offs, architectural evolution across versions (e.g. why move from Node to Rust), lessons learned from failure, conscious rejection of standard approaches with reasoning. |
| `ux-interaction` | Non-obvious UI patterns, accessibility strategies, feedback loops, information architecture decisions. Must solve a specific UX problem in a non-standard way. |
| `process` | Development workflows, project management patterns, tooling decisions, team coordination strategies, CI/CD philosophies. Must encode hard-won experience, not standard agile/scrum. |
| `creative-vision` | Art direction choices, aesthetic systems, visual language rules, procedural generation philosophies, style guides with reasoning. Must articulate *why* specific creative choices were made. |

### Tag taxonomy

Tags must be lowercase kebab-case. Use atomic tags, not compound ones:
- Technology: `drupal`, `php`, `javascript`, `python`, `react`, `sql`, `bash`
- Subsystem: `views`, `twig`, `webpack`, `docker`, `nginx`, `cron`
- Concept: `caching`, `auth`, `form-api`, `migrations`, `config-api`, `hooks`
- Domain: `performance`, `security`, `ui`, `api`, `cli`, `testing`
- Game design: `game-mechanics`, `balancing`, `economy`, `progression`, `combat`, `rpg`, `tcg`, `roguelike`, `mmo`
- Creative: `world-building`, `narrative`, `lore`, `art-direction`, `procedural-generation`
- Process: `workflow`, `methodology`, `tooling`, `architecture-evolution`

Never: `drupal-views` (split into `drupal` + `views`), CamelCase, project names as concept tags (use `PROJECT_TAG` instead).

### Not worth extracting

**Technical:** Standard CRUD, libraries used as intended, boilerplate, self-evident config, standard patterns used standardly, anything a competent developer arrives at in <5 minutes.

**Non-technical:** Generic genre descriptions ("it's an RPG"), obvious game mechanics ("players gain XP"), standard UI layouts, placeholder lore without internal structure, TODO lists without reasoning. The bar is the same: would someone with domain experience say "interesting" or "obvious"?

### Per-concept deduplication (cross-project)

Compare each extracted concept against ALL notes in `KNOWN_NOTES` (entire vault, not just this project):

**Case A — Genuinely new concept** (no matching note anywhere in vault):
- Action: `CREATE` — new file, `found_in: [PROJECT_NAME]`

**Case B — Same concept, same project, no new info:**
- Action: `SKIP`

**Case C — Same concept, same project, new details found:**
- Action: `EXTEND` — append `## Integrazione (YYYY-MM-DD)` section, update `updated`, raise any score dimension (`novelty`, `applicability`, `reusability`) if the new information justifies it, recalculate `score`

**Case D — Same concept found in a different project** (title/description matches existing note from another project):
- Action: `FOUND_IN` — add `PROJECT_NAME` to the existing note's `found_in` array, add current `source` to `source` field, optionally append a one-line context note under `## Visto anche in (PROJECT_NAME)` if the usage context differs meaningfully
- Do NOT create a new file

**Similarity check for Case D:** titles are similar if they describe the same underlying mechanism. Use judgment: "auto-registrazione DisplayExtender via hook_install" and "registrazione automatica plugin via install hook" describe the same thing → Case D.

---

## Phase 5 — Native Files

View each NATIVE file with Read tool. Extract a note if:
- **Technical:** diagrams, architecture charts, flow diagrams with non-obvious structure
- **Creative:** concept art showing a coherent art direction or visual language system, character design sheets with systematic rules, world maps with internal geographic logic
- **Design:** game design documents (PDF/images) with mechanics, balancing tables, progression curves

Skip: generic images, icons, screenshots, placeholder art, stock assets.

---

## Phase 6 — Deduplication Pass

After extracting all concepts: if two newly-extracted concepts describe the same idea → merge into one `CREATE`. The merged note uses the more descriptive title; the `source` list is the union of the two source file paths.

---

## Phase 7 — Decide Actions & Build see_also

Classify each concept: `CREATE` / `EXTEND` / `FOUND_IN` / `SKIP`. Count each.

**For every concept marked CREATE or EXTEND**, build `see_also`:
- Compare the concept's title, category, and tags against all `KNOWN_NOTES`
- If a note in the vault is conceptually related (same domain, complementary mechanism, or prerequisite knowledge) → add its plain slug (without `.md`, without brackets) to `see_also`. Wikilinks go only in the note body — frontmatter slugs must be plain strings for Dataview queries.
- Also cross-link concepts extracted in this same pass if they are related
- Limit: max 5 entries. If more than 5 are relevant, prefer in order: (1) stessa `category`, (2) `score` più alto, (3) ordine alfabetico per slug. Se nessun candidato → ometti il campo `see_also` e la riga `Vedi anche` interamente (non scrivere `[]`).

---

## Phase 8 — Write Files & Update Index

**Filename:** `<concept-slug>.md` (kebab-case, max 60 chars). No project suffix — notes are canonical across projects. If a slug already exists in the vault for a *different* concept (different title/meaning), append `-2`, `-3`, etc. until unique. If the slug exists for the *same* concept → it's a FOUND_IN or EXTEND case, not a collision.

**New notes (CREATE):** one Write call per file to `<VAULT_PATH>/notes/<filename>.md`:

```markdown
---
title: "[Titolo conciso — l'idea, non il file]"
category: CATEGORY
novelty: 1-3
applicability: 1-3
reusability: 1-3
score: 0-10
found_in: [PROJECT_NAME]
source: [relative/path/to/file.ext]
tags: [tag1, tag2, PROJECT_TAG]
see_also: [related-slug, other-slug]
date: YYYY-MM-DD
updated:
pass: CURRENT_PASS
---

**Descrizione:** [1–3 frasi autocontenute.]

**Perché non-ovvio:** [Alternativa default e perché questa è diversa.]

**Ricostruzione:**
[Per categorie tecniche: pseudocodice ≤8 righe. Obbligatorio per `algoritmo` e `frammento`. Opzionale per `hack` (includi se la sequenza è non-ovvia). Ometti per `conoscenza-di-dominio` e `decisione` (la prosa è sufficiente).]
[Per categorie non-tecniche: descrizione strutturata del sistema/decisione. Per `game-design`: il loop/meccanica con parametri chiave. Per `world-building`: la struttura narrativa/cosmologica. Per `design-philosophy`: il trade-off e le alternative scartate. Per `creative-vision`: le regole estetiche. Ometti per `process` se la prosa è sufficiente.]

**Quando riapplicare:** [Una frase: in quale scenario futuro questa soluzione/insight torna utile. Ometti per `frammento` e `conoscenza-di-dominio`.]

---
*Vedi anche: [[related-slug]] · [[other-slug]]*
```
(Se nessun candidato: ometti sia `see_also` dal frontmatter che la riga `Vedi anche` dal corpo)

Note:
- `CATEGORY`: scegli uno tra `algoritmo`, `pattern-architetturale`, `hack`, `conoscenza-di-dominio`, `decisione`, `frammento`, `game-design`, `world-building`, `design-philosophy`, `ux-interaction`, `process`, `creative-vision`
- `source` is always a YAML list (even with one item) — avoids type mutation on future FOUND_IN updates
- `tags` always ends with `PROJECT_TAG` — enables Obsidian tag panel navigation by project
- `see_also` in frontmatter: plain slugs (no brackets) — for Dataview queries
- `Vedi anche` line in body: `[[wikilinks]]` — creates real Obsidian graph edges and clickable links

**Extended notes (EXTEND):** append to existing file:
```markdown

## Integrazione (YYYY-MM-DD) — passata CURRENT_PASS
[Solo le informazioni nuove.]
```
Update frontmatter: `updated: YYYY-MM-DD`. Raise any score dimension (`novelty`, `applicability`, `reusability`) if the new information justifies it; recalculate `score` if any dimension changes. Add `PROJECT_TAG` to `tags` if not already present. If note is missing `applicability`, `reusability`, or `score`, add them now (estimated from context).

**Cross-project notes (FOUND_IN):** Read the existing file first, then use Edit to update frontmatter:
- Add `PROJECT_NAME` to `found_in` array if not already present
- Add `PROJECT_TAG` to `tags` array if not already present
- Add current source path to `source` list if not already present
- **Replace** the existing `updated:` line (whether empty or with a date) with `updated: YYYY-MM-DD` — do NOT add a second `updated:` line. Use Edit with the old `updated:` value (including empty) as `old_string`.
- If usage context differs meaningfully, append:
```markdown

## Visto anche in PROJECT_NAME
[Una frase su come viene usato diversamente in questo progetto, se diverso.]
```

**Project index** — Write `<VAULT_PATH>/_index/<PROJECT_NAME>.md`:

**BEFORE writing:** always check if the index file already exists and read it first. Never blindly overwrite an index with `cat >` or similar — it destroys previous pass history and concept counts. If the file exists, use Edit to update specific fields (passes, concepts, updated, Storico row) rather than rewriting the whole file.

On **first pass** (no existing index): create from scratch with Write tool, `status: wip`.
On **subsequent passes**: Read the existing file first, then Edit only: `passes:`, `concepts:`, `updated:`, `avg_score:`, and the Storico table (append new row). Preserve everything else verbatim.

Note sul template:
- `STATUS`: `wip` solo sulla prima passata; sulle successive usa `EXISTING_STATUS`
- `concepts`: totale cumulativo di note nel vault con `PROJECT_NAME` in `found_in` (tutte le passate, non solo questa)
- `avg_score`: `VAULT_AVG_SCORE` — media cumulativa su tutti i concetti del progetto che hanno `score`; ometti se nessuno ha ancora `score`
- Colonna `Score medio` Storico: `PASS_AVG_SCORE` — solo i concetti CREATE + EXTEND di quella passata; usa `-` per righe precedenti senza dato

```markdown
---
project: PROJECT_NAME
source_path: ROOT
status: STATUS
first_distilled: FIRST_DISTILLED
updated: YYYY-MM-DD
passes: CURRENT_PASS
concepts: N_TOTAL
avg_score: X.X
---

# PROJECT_NAME

## Storico passate
| Passata | Data | Nuovi | Estesi | Found-in | Saltati | Score medio |
|---------|------|-------|--------|----------|---------|-------------|
[STORICO_ROWS — all previous rows preserved, new row appended]
| CURRENT_PASS | YYYY-MM-DD | N | N | N | N | X.X |

## Concetti di questo progetto
\```dataview
TABLE category, novelty, applicability, reusability, score, found_in
FROM "notes"
WHERE contains(found_in, "PROJECT_NAME")
SORT score DESC
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
  Score medio questa passata: X.X / 10

  Distribuzione score (nuovi + estesi):
    9-10  N concetti  ████
     7-8  N concetti  ██
     5-6  N concetti  █
     0-4  N concetti

Quando sei soddisfatto → imposta status: review in _index/PROJECT_NAME
```

**Dopo aver scritto tutte le note**, calcola:
- `N_TOTAL` = numero di note nel vault con `PROJECT_NAME` in `found_in` — comprende sia le note create da questo progetto che quelle di altri progetti in cui è stato aggiunto come FOUND_IN. Calcola con:
  ```bash
  grep -rl "found_in:.*\"PROJECT_NAME\"" "<VAULT_PATH>/notes/" 2>/dev/null | wc -l
  ```
  Non usare `N_PROJECT_NOTES + CREATE_COUNT` — quella formula non conta i FOUND_IN ricevuti.
- `PASS_AVG_SCORE` = media dei `score` dei concetti CREATE + EXTEND di questa passata, arrotondata a 1 decimale (es. `6.3`) → usato nella colonna Storico e nel console output. Se 0 CREATE + EXTEND → `PASS_AVG_SCORE = -` (scrivi `-` nella colonna e ometti la riga "Score medio questa passata" dal console output)
- `VAULT_AVG_SCORE` = media di tutti i `score` delle note nel vault con `PROJECT_NAME` in `found_in` (escludendo note senza `score`), arrotondata a 1 decimale (es. `7.1`); se nessuna nota ha `score` → ometti il campo `avg_score` dall'index

**Bar chart**: 1 `█` per concetto fino a 8; se una fascia supera 8, scala proporzionalmente tutte le fasce (max 8 `█`).

---

## Multi-project batch strategy

When distilling multiple projects in a single session (e.g. scanning an entire DevDrive):

1. **Process one project at a time** — complete all 8 phases for project N before starting project N+1. Do not defer index writing to a batch at the end.
2. **Write the index immediately after each project** — this ensures that if context pressure cuts the session short, all completed projects have accurate indexes. A deferred batch write is the primary cause of index overwrite errors.
3. **Rebuild KNOWN_NOTES grep at session start, then keep it in-context** — the grep title index from Phase 1 should be run once and kept as a compact text reference. Do not re-grep before every project; do not discard it between projects.
4. **If context is near limit mid-project**: write the notes extracted so far, write the index as `(parziale)`, then stop. Do not start the next project.

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
7. **I punteggi sono onesti su tutte e 3 le dimensioni.** Il 3 in qualsiasi dimensione deve essere davvero giustificato — resisti all'inflazione verso l'alto su `novelty`, `applicability` e `reusability`.
8. **Prosa prima, codice solo se necessario** (≤8 righe).
9. **Nessuna domanda a metà.**
10. **Il vault deve sopravvivere alla cancellazione del progetto.**
11. **`tags` include sempre `PROJECT_TAG`** — mai omettere, è il ponte tra Dataview e navigazione Obsidian nativa.
12. **`--exclude-dir` usa nomi directory, non path** — `contrib` e `core`, non `modules/contrib`.
13. **`_index` Storico è cumulativo** — le righe delle passate precedenti non si cancellano mai.
14. **`source` è sempre una lista YAML** — anche con un solo elemento, per coerenza con gli aggiornamenti FOUND_IN.
15. **PROJECT_NAME è normalizzato** — kebab-case, minuscolo, senza caratteri speciali.
16. **`status` non si resetta mai** — sulla prima creazione è `wip`; sulle passate successive si preserva `EXISTING_STATUS`. Un `done` non diventa mai `wip` automaticamente.
17. **LAST_PASS dall'index, non dalle note** — `passes:` nell'index è la fonte autoritativa; le note non vengono aggiornate su EXTEND.
18. **`Vedi anche` nel corpo, `see_also` nel frontmatter** — i wikilink nel corpo creano connessioni reali nel grafo Obsidian; il frontmatter è per Dataview.
19. **`score` è sempre calcolato, mai omesso.** Per ogni nota CREATE usa la formula composita: `round(((novelty-1)*0.45 + (applicability-1)*0.35 + (reusability-1)*0.20) / 2 * 10)`. Per EXTEND aggiorna `score` se `novelty`, `applicability` o `reusability` cambiano. Per FOUND_IN il `score` rimane invariato (appartiene al concetto, non al progetto corrente).
20. **KNOWN_NOTES via grep, non via lettura file.** Phase 1 costruisce l'indice con `grep -rh "^title:"` e `grep -rh "^found_in:"` — non aprendo ogni nota. Aprire singole note solo per verificare un potenziale match. Ignorare questa regola porta a note duplicate cross-sessione.
21. **Index: leggi prima di scrivere.** Se `_index/<PROJECT_NAME>.md` esiste, aprilo con Read e usa Edit per aggiornare solo i campi che cambiano. Non usare Write o bash redirection su un index esistente — distrugge lo Storico delle passate precedenti.
22. **`concepts:` conta tutto il vault, non solo i CREATE.** Il valore è `grep -rl "found_in:.*\"PROJECT_NAME\"" notes/ | wc -l`. Include note CREATE di questo progetto, FOUND_IN ricevuti da altri progetti, e EXTEND. Non calcolarlo come `N_PROJECT_NOTES + nuovi_CREATE` — quella formula non conta i FOUND_IN ricevuti.
23. **`3` richiede giustificazione difendibile.** Prima di assegnare 3 in qualsiasi dimensione, formulare mentalmente la frase: *"È un 3 perché..."*. Se la frase è vaga o incerta, è un 2. Il dubbio va sempre verso il basso.
24. **Portabilità: comandi bash devono funzionare su Linux, macOS e Windows (Git Bash).** Usare `-E` (ERE) per alternazioni (`|`), mai BRE `\|` (macOS BSD grep non lo supporta). Usare `|| true` su `find` e `grep -rl` che possono uscire con codice non-zero quando non trovano nulla. Mai `grep -P` (PCRE) — macOS BSD grep non lo supporta.
25. **No campi YAML duplicati nel frontmatter.** Prima di aggiungere o aggiornare un campo (`updated`, `tags`, `found_in`, ecc.), Read il file e usa Edit per **sostituire** la riga esistente. Non aggiungere mai una seconda riga con lo stesso nome campo — YAML prende solo l'ultima, Obsidian/Dataview possono rompersi. Questo vale per FOUND_IN, EXTEND, e qualsiasi modifica a note esistenti.
