---
name: kvault
description: Query the knowledge vault semantically. Searches INDEX.md for relevant
  notes by project, technology, or concept, reads the full notes, and answers
  the question citing sources with slug and score.
version: 1.3.0
context: fork
agent: general-purpose
allowed-tools: Read, Grep, Glob, Bash
argument-hint: <question-or-topic> [vault-path]
---

You are running the **kvault** skill — a lightweight query tool for the knowledge vault.

---

**Portability:** all bash commands must work on Linux, macOS, AND Windows (Git Bash). Use `|| true` on commands that may fail.

## Phase 1 — Parse Arguments & Resolve Vault

Parse `$ARGUMENTS`:
- If the **last token** looks like an absolute path (starts with `/` or `X:/`), use it as `VAULT_PATH` and everything before it is the `QUESTION`.
- Otherwise: `VAULT_PATH = D:/knowledge`, full `$ARGUMENTS` is the `QUESTION`.
- If `QUESTION` is empty or blank: show the top notes by score (read `VAULT_PATH/INDEX.md`, print up to 10 data rows after the header — if fewer than 10 data rows exist, print all of them) and stop.

**Check INDEX.md exists:**
```bash
test -f "<VAULT_PATH>/INDEX.md" && echo "OK" || echo "MISSING"
```
If OK, verify it has data rows:
```bash
wc -l < "<VAULT_PATH>/INDEX.md"
```
If line count <= 5 (header only, no data): reply with `INDEX.md è vuoto. Rigenera con: bash <VAULT_PATH>/gen-index.sh` and stop.

If MISSING: reply with `INDEX.md non trovato in <VAULT_PATH>. Genera con: bash <VAULT_PATH>/gen-index.sh` and stop.

---

## Phase 2 — Pre-read Context (conditional)

**If the QUESTION contains a file path** (e.g. `src/foo.js`, `C:/Users/.../bar.py`, `.\src\bar.py`):
- Detect file paths by looking for tokens containing `/` or `\` with a file extension, OR absolute paths starting with `/` or `X:/` or `X:\`. Normalize Windows backslashes to forward slashes before use.
- Read that file first.
- Extract its main themes, technologies, and patterns.
- Use those themes as additional search terms in Phase 3.

---

## Phase 3 — Search INDEX.md

Read `<VAULT_PATH>/INDEX.md`.
Format: `score | slug | categoria | tag | progetti | titolo`
- Ordered by score descending (10 = max).

Identify relevant notes by semantic match with the QUESTION:
- By project name → filter `progetti` column
- By technology → filter `tag` column
- By concept/pattern → match against `titolo` column
- Use themes extracted in Phase 2 if applicable

**Category filter:** if the user asks for a category of knowledge (e.g. "what algorithms do I know?", "show me all hacks"), filter INDEX.md by the `categoria` column:
- "algorithms" / "algoritmi" → filter `algoritmo`
- "patterns" / "architettura" → filter `pattern-architetturale`
- "hacks" / "workaround" → filter `hack`
- "snippets" / "frammenti" → filter `frammento`

Select at most **5 notes** (prefer score >= 7 at equal relevance).

**If the QUESTION targets a specific project**, also read `<VAULT_PATH>/_index/<project-name>.md` for the `## Concetti di questo progetto` section to find additional relevant slugs.

**Fallback search:** if INDEX.md search found fewer than 2 relevant notes, do a direct grep on notes/ to catch cases where INDEX.md is stale or the query uses terms not in titles/tags:
```bash
# Fallback: search note titles and content directly
grep -rl "<search-terms>" "<VAULT_PATH>/notes/" 2>/dev/null | head -5 || true
```

---

## Phase 4 — Read & Answer

Read the selected note files from `<VAULT_PATH>/notes/<slug>.md`.

**Answer the question** citing each note used (slug + score).
If no note is relevant, say so explicitly.

---

## Output Format

For concept queries, answer with:
1. Direct answer to the question
2. Relevant notes listed as: `slug` (score N) — one-line summary
3. If applicable: code snippet from the note's Ricostruzione section

For project queries, include:
1. Project summary from _index ## Note
2. All concepts from that project, sorted by score
3. Vault coverage assessment (well-covered / gaps exist)

Keep answers concise. Cite every note used.
