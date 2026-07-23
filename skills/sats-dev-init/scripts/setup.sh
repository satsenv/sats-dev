#!/usr/bin/env bash
# setup.sh — bootstrap a devenv project preconfigured with sats-dev.
#
# This helper does the mechanical parts (mkdir, `devenv init`, first eval).
# The agent (or human) is still responsible for writing the actual
# devenv.yaml / devenv.nix content — see ../references/*.example.
#
# Usage:
#   scripts/setup.sh <target-dir> [--force]
#
# Env overrides:
#   SKIP_EVAL=1   # don't run `devenv shell -- true` at the end

set -euo pipefail

TARGET_DIR="${1:-}"
FORCE="${2:-}"

if [[ -z "$TARGET_DIR" ]]; then
  echo "usage: $0 <target-dir> [--force]" >&2
  exit 2
fi

# 1. Prerequisites
for cmd in devenv nix; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "error: '$cmd' not found in PATH. See https://devenv.sh/getting-started/" >&2
    exit 1
  fi
done

# 2. Prepare target
mkdir -p "$TARGET_DIR"
cd "$TARGET_DIR"

if [[ -f devenv.nix && "$FORCE" != "--force" ]]; then
  echo "error: $TARGET_DIR already contains devenv.nix (pass --force to overwrite)" >&2
  exit 1
fi

# 3. devenv init (only if needed)
if [[ ! -f devenv.nix ]]; then
  devenv init
fi

# 4. First evaluation — locks inputs and validates the module set.
if [[ "${SKIP_EVAL:-0}" != "1" ]]; then
  echo ">>> Running: devenv shell -- true"
  devenv shell -- true
fi

echo ">>> Done. Project initialized at: $(pwd)"
