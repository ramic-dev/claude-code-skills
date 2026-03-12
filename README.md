# Claude Code Skills

A collection of custom skills for [Claude Code](https://docs.anthropic.com/en/docs/claude-code) by [@ramic-dev](https://github.com/ramic-dev).

---

## What are Claude Code skills?

Skills are slash commands (`/skillname`) that give Claude Code a structured, reusable prompt with its own tools, context mode, and execution flow. They live in `~/.claude/skills/<name>/SKILL.md`.

---

## Skills

### [`/triage`](./triage/) — Personal Archive Triager

Maps a large collection of mixed personal data and projects using filesystem metadata only — no file reading. Assigns every directory a disposition and produces a prioritized action plan.

**Use it when:**
- You have GBs of projects and data to sort through before a cleanup
- You want to know what should go on GitHub (public vs private), what to cloud-backup, and what to delete
- You can't manually map the structure yourself

**What it does:**
1. Builds a size map of all top-level directories
2. Detects code project roots (git, package.json, Cargo.toml, etc.)
3. Classifies non-project directories (media, docs, backups, junk)
4. Detects cleanable junk (orphaned node_modules, build artifacts, caches)
5. Assigns each item a disposition: GitHub Public / GitHub Private / Cloud Storage / Delete / needs `/preserve` / Manual Review
6. Writes `triage-report.md` with a full action plan and recoverable space estimate

**Works on any size collection** — metadata-only scan means it handles 10GB or 100GB in the same time.

---

### [`/preserve`](./preserve/) — Project Preservation Scanner

Scans every file in a single project directory and produces a `preservation-report.md` identifying the content most worth saving before it gets deleted or lost.

**Use it when:**
- About to delete or archive a specific project
- Migrating or handing off a codebase
- Wanting to audit what unique knowledge, algorithms, or design decisions live in the code

**What it does:**
1. Discovers all files, partitions into TEXT / PDF+images / binary
2. Reads everything it can (handles unknown extensions via null-byte check)
3. Scores each file 0–10 using a three-tier heuristic (algorithms, domain knowledge, design decisions)
4. Ranks findings and selects the TOP 10 most valuable items
5. Writes a structured `preservation-report.md` with key snippets and specific preservation actions

**Typical workflow:** run `/triage` on the whole archive first to find which projects need attention, then run `/preserve` on each flagged project for a deep content scan.

---

## Install

**One-liner:**
```bash
# Install both skills
curl -fsSL https://raw.githubusercontent.com/ramic-dev/claude-code-skills/main/install.sh | bash -s triage preserve

# Install individually
curl -fsSL https://raw.githubusercontent.com/ramic-dev/claude-code-skills/main/install.sh | bash -s triage
curl -fsSL https://raw.githubusercontent.com/ramic-dev/claude-code-skills/main/install.sh | bash -s preserve
```

**From a local clone:**
```bash
git clone https://github.com/ramic-dev/claude-code-skills.git
bash claude-code-skills/install.sh triage preserve
```

Then open a new Claude Code session and type `/triage` or `/preserve`.

---

## Usage

```
/triage                        # triage current directory
/triage /path/to/my/archive    # triage a specific path

/preserve                      # scan current project
/preserve /path/to/project     # scan a specific project
```

---

## Repository structure

```
claude-code-skills/
├── install.sh
├── triage/
│   └── SKILL.md
├── preserve/
│   ├── SKILL.md
│   └── docs/
│       └── binary-extensions.md
└── ...
```
