# Claude Code Skills

A collection of custom skills for [Claude Code](https://docs.anthropic.com/en/docs/claude-code) by [@ramic-dev](https://github.com/ramic-dev).

---

## What are Claude Code skills?

Skills are slash commands (`/skillname`) that give Claude Code a structured, reusable prompt with its own tools, context mode, and execution flow. They live in `~/.claude/skills/<name>/SKILL.md`.

---

## Skills

### [`/preserve`](./preserve/) — Project Preservation Scanner

Scans every file in a project directory and produces a `preservation-report.md` identifying the content most worth saving before it gets deleted or lost.

**Use it when:**
- About to delete or archive a project
- Migrating or handing off a codebase
- Wanting to audit what unique knowledge, algorithms, or design decisions live in the code

**What it does:**
1. Discovers all files, partitions into TEXT / PDF+images / binary
2. Reads everything it can (handles unknown extensions via null-byte check)
3. Scores each file 0–10 using a three-tier heuristic (algorithms, domain knowledge, design decisions)
4. Ranks findings and selects the TOP 10 most valuable items
5. Writes a structured `preservation-report.md` with key snippets and specific preservation actions

**Example output:** TOP 10 with score breakdowns, full inventory tables, skipped/unreadable file lists, and a summary of what makes the project unique.

---

## Install

**One-liner (single skill):**
```bash
curl -fsSL https://raw.githubusercontent.com/ramic-dev/claude-code-skills/main/install.sh | bash -s preserve
```

**From a local clone:**
```bash
git clone https://github.com/ramic-dev/claude-code-skills.git
bash claude-code-skills/install.sh preserve
```

**Manual:**
```bash
mkdir -p ~/.claude/skills/preserve
curl -fsSL https://raw.githubusercontent.com/ramic-dev/claude-code-skills/main/preserve/SKILL.md \
  -o ~/.claude/skills/preserve/SKILL.md
```

Then open a new Claude Code session and type `/preserve` in any project directory.

---

## Usage

```
/preserve                    # scan current directory
/preserve /path/to/project   # scan a specific path
```

The report is written to `preservation-report.md` in the scanned directory. Subsequent runs archive the previous report automatically.

---

## Repository structure

```
claude-code-skills/
├── install.sh
├── preserve/
│   ├── SKILL.md              ← skill prompt (copy this to ~/.claude/skills/preserve/)
│   └── docs/
│       └── binary-extensions.md  ← extension classification reference
└── ...
```
