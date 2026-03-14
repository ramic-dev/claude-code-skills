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

---

### [`/distill`](./distill/) — Knowledge Distillation

Reads every file in a project, extracts non-obvious concepts, and writes one markdown note per concept to an Obsidian vault — with scoring, cross-project deduplication, and Dataview compatibility.

**Use it when:**
- You want to extract reusable knowledge from a project before archiving it
- Building a personal knowledge base of patterns, algorithms, and design decisions
- Running a census across many projects to find what's unique

**What it does:**
1. Scans all source files for non-obvious patterns, algorithms, hacks, and domain knowledge
2. Scores each concept on three dimensions: novelty, applicability, reusability (composite score 0-10)
3. Deduplicates across the entire vault — same concept in two projects = one note with `found_in: [project1, project2]`
4. Writes atomic markdown notes with YAML frontmatter, compatible with Obsidian + Dataview
5. Maintains a per-project index with pass history and concept counts

---

### [`/review-project`](./review-project/) — Project Evaluator

Analyzes a project directory and produces a structured evaluation report to help decide: complete and publish to GitHub, or archive.

**Use it when:**
- Reviewing a backlog of old projects one by one
- You need a quick assessment before investing time running a project manually
- Deciding between "keep and publish" vs "extract knowledge and discard"

**What it does:**
1. Maps project structure, file types, and code volume
2. Identifies tech stack, entry points, and run commands
3. Assesses completeness (Skeleton → Prototype → MVP → Mature → Polished)
4. Checks vault coverage — what knowledge has already been extracted
5. Produces a recommendation: **KEEP** (publish), **ARCHIVE** (discard), or **NEEDS-TESTING** (run it first)
6. Lists specific action items for the chosen path

---

### [`/ship`](./ship/) — GitHub Publication Prep

Prepares a project for GitHub publication — generates missing scaffolding, identifies cleanup needed, and produces a pre-push checklist.

**Use it when:**
- A project passed `/review-project` with KEEP recommendation
- You want to publish a project but it's missing README, .gitignore, LICENSE
- You need a final check before pushing to GitHub

**What it does:**
1. Generates or improves README.md (in English, from actual code — not aspirational)
2. Creates .gitignore tailored to the detected tech stack
3. Adds LICENSE file if missing
4. Identifies artifacts to clean (logs, temp files, large binaries, secrets)
5. Checks git status and suggests remote setup
6. Produces a pre-push checklist with project-specific items

**Never pushes or commits automatically** — all destructive actions are left to the user.

---

### [`/kvault`](./kvault/) — Knowledge Vault Query

Queries an Obsidian knowledge vault semantically. Loads a compact index, identifies relevant notes by project/technology/concept, reads them, and answers citing sources.

**Use it when:**
- You want to check what patterns you already know before coding
- Evaluating if a project's knowledge has been captured
- Looking for a specific algorithm or technique across all projects

**What it does:**
1. Loads INDEX.md (compact manifest of all notes: score, slug, category, tags, projects, title)
2. Matches the query semantically against titles, tags, and project names
3. Reads the full notes for the top matches
4. Answers citing slug and score

---

## Typical Workflow

```
/triage /path/to/archive          # 1. Map everything, find what matters
/preserve /path/to/project        # 2. Deep-scan projects flagged for review
/distill /path/to/project         # 3. Extract knowledge into vault
/kvault "what do I know about X?" # 4. Query the vault
/review-project /path/to/project  # 5. Evaluate: keep or discard?
/ship /path/to/project            # 6. Prepare keeper projects for GitHub
```

---

## Install

**One-liner:**
```bash
# Install all skills
curl -fsSL https://raw.githubusercontent.com/ramic-dev/claude-code-skills/main/install.sh | bash -s triage preserve distill review-project ship kvault

# Install individually
curl -fsSL https://raw.githubusercontent.com/ramic-dev/claude-code-skills/main/install.sh | bash -s review-project
curl -fsSL https://raw.githubusercontent.com/ramic-dev/claude-code-skills/main/install.sh | bash -s kvault
```

**From a local clone:**
```bash
git clone https://github.com/ramic-dev/claude-code-skills.git
bash claude-code-skills/install.sh triage preserve distill review-project ship kvault
```

Then open a new Claude Code session and type any skill name.

---

## Usage

```
/triage                            # triage current directory
/triage /path/to/archive           # triage a specific path

/preserve                          # scan current project
/preserve /path/to/project         # scan a specific project

/distill /path/to/project          # extract knowledge to vault
/distill /path/to/project ~/vault  # specify custom vault path

/review-project /path/to/project   # evaluate a project
/ship /path/to/project             # prepare for GitHub
/ship /path/to/project --license Apache-2.0 --org myuser

/kvault "sqlite concurrency"       # search vault by concept
/kvault "idle-job-simulator"       # check vault coverage for a project
/kvault                            # show top 10 notes by score
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
├── distill/
│   └── SKILL.md
├── review-project/
│   └── SKILL.md
├── ship/
│   └── SKILL.md
├── kvault/
│   └── SKILL.md
└── ...
```
