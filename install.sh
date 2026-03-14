#!/usr/bin/env bash
# install.sh — Install Claude Code skills from ramic-dev/claude-code-skills
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/ramic-dev/claude-code-skills/main/install.sh | bash -s preserve
#   curl -fsSL https://raw.githubusercontent.com/ramic-dev/claude-code-skills/main/install.sh | bash -s preserve other-skill
#   bash install.sh preserve          # local clone

set -euo pipefail

REPO_RAW="https://raw.githubusercontent.com/ramic-dev/claude-code-skills/main"
SKILLS_DIR="${CLAUDE_SKILLS_DIR:-$HOME/.claude/skills}"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd || echo "")"

skills=("$@")
if [ ${#skills[@]} -eq 0 ]; then
  echo "Usage: install.sh <skill> [skill2 ...]"
  echo "Available skills: distill preserve triage review-project ship kvault"
  exit 1
fi

install_skill() {
  local skill="$1"
  local dest="$SKILLS_DIR/$skill"

  echo "Installing skill: $skill → $dest"
  mkdir -p "$dest"

  if [ -n "$REPO_ROOT" ] && [ -f "$REPO_ROOT/$skill/SKILL.md" ]; then
    # Local install from cloned repo
    cp -r "$REPO_ROOT/$skill/." "$dest/"
  else
    # Remote install via curl
    if ! command -v curl &>/dev/null; then
      echo "Error: curl is required for remote install." >&2; exit 1
    fi
    curl -fsSL "$REPO_RAW/$skill/SKILL.md" -o "$dest/SKILL.md"
    # Download docs if present
    mkdir -p "$dest/docs"
    curl -fsSL "$REPO_RAW/$skill/docs/binary-extensions.md" \
      -o "$dest/docs/binary-extensions.md" 2>/dev/null || true
  fi

  echo "✓ $skill installed. Use it with: /$skill"
}

for skill in "${skills[@]}"; do
  install_skill "$skill"
done
