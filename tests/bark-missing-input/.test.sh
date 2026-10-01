#!/usr/bin/env bash
set -e

# Swap in the fixture that enables services.bark without the flake input,
# then assert evaluation fails with actionable instructions.
cp fixture/devenv.nix devenv.nix

if devenv shell -- true 2> eval-error.log; then
  echo "expected evaluation to fail without the bark input, but it succeeded" >&2
  exit 1
fi

if grep -q "services.bark" eval-error.log && grep -q "gitlab:ark-bitcoin/bark" eval-error.log; then
  echo "missing input produces instructions mentioning services.bark and the flake URL" >&2
else
  echo "eval failed but without the expected guidance:" >&2
  cat eval-error.log >&2
  exit 1
fi

echo "bark-missing-input test passed" >&2
