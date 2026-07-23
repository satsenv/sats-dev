---
name: sats-dev-init
description: Initialize a new devenv project with sats-dev modules for Bitcoin/Lightning development (bitcoind, lnd, clightning, lnbits, nostr-rs-relay, podman-machine)
---

# sats-dev devenv initializer

This skill sets up a fresh [devenv](https://devenv.sh) project preconfigured
with the [sats-dev](https://github.com/satsenv/sats-dev) modules — reusable
devenv modules for the Bitcoin and Lightning stack.

## Layout

```
sats-dev-init/
├── SKILL.md              # this file — always in context when the skill is loaded
├── scripts/              # helper scripts, invoke on demand
│   └── setup.sh          # mkdir + `devenv init` + first evaluation
└── references/           # supporting docs & examples, load on demand
    ├── devenv.yaml.example
    └── devenv.nix.example
```

The agent should keep this `SKILL.md` in context, and load `references/` files
or invoke `scripts/setup.sh` **only when needed** — this keeps the context
window small.

## When to use

Trigger this skill when the user asks to:
- "Create a devenv with sats-dev"
- "Bootstrap a Bitcoin/Lightning devenv"
- "Set up a regtest environment with bitcoind/lnd/clightning/lnbits/nostr-rs-relay"

## Prerequisites

Verify before proceeding — do NOT try to install these silently:
- `command -v devenv`
- `command -v nix`

If either is missing, point the user to https://devenv.sh/getting-started/ and stop.

## Inputs to gather from the user

Ask in a single message:

1. **Target directory** — where to initialize (default: cwd).
   Refuse to overwrite an existing `devenv.nix` unless the user passes
   `--force` (or explicitly confirms).
2. **Which sats-dev services** to enable. Multi-select from:
   - `bitcoind` (regtest by default)
   - `lnd` (auto-enables bitcoind)
   - `clightning` (auto-enables bitcoind)
   - `lnbits` (needs an external `package` — ask for the flake input or skip)
   - `nostr-rs-relay`
   - `podman-machine`
3. **Network mode** for bitcoind: `regtest` (default) or `mainnet`.
4. **sats-dev source**: default `github:satsenv/sats-dev?dir=src/modules`.
   For a local checkout, use `path:/absolute/path?dir=src/modules`.

If the user says "just do it" / "defaults", use: **bitcoind + lnd on regtest**,
from the github source.

## Procedure

### Step 1 — Bootstrap the project skeleton

Run the helper script:

```bash
scripts/setup.sh <target-dir>          # add --force to overwrite an existing devenv.nix
```

This will:
- verify prerequisites
- `mkdir -p` the target
- run `devenv init` if `devenv.nix` doesn't exist yet
- run `devenv shell -- true` to lock inputs (skip via `SKIP_EVAL=1`)

Do NOT run the evaluation step yet if you still need to write custom
`devenv.yaml` / `devenv.nix` — pass `SKIP_EVAL=1` and run `devenv shell -- true`
manually after step 3.

### Step 2 — Write `devenv.yaml`

Load `references/devenv.yaml.example` on demand for the exact shape. Minimal
required content:

```yaml
inputs:
  nixpkgs:
    url: github:cachix/devenv-nixpkgs/rolling
  upstream-devenv:                       # REQUIRED — see note below
    url: github:cachix/devenv?dir=src/modules
  sats-dev:
    url: github:satsenv/sats-dev?dir=src/modules
imports:
  - sats-dev
```

> ⚠ sats-dev's `top-level.nix` references `inputs.upstream-devenv`. Omitting
> that input fails evaluation with `error: attribute 'upstream-devenv' missing`.

Add an `lnbits:` input only if the user selected lnbits.

### Step 3 — Write `devenv.nix`

Load `references/devenv.nix.example` for a template with every service listed
(commented). Enable **only** what the user asked for.

Verified module facts (see sats-dev README):

- `services.bitcoind` — options: `regtest`, `rpcAddress`, `rpcPort`, `rpcUser`,
  `rpcPassword`, `extraConfig`. Exports `BITCOIN_RPC_URL`.
- `services.lnd` — auto-enables `services.bitcoind`. Exports `LND_CERT_FILE`,
  `LND_MACAROON_FILE`, `LND_GRPC_HOST`.
- `services.clightning` — auto-enables `services.bitcoind`.
- `services.lnbits` — **requires**
  `package = inputs.lnbits.packages.${pkgs.stdenv.hostPlatform.system}.default;`
  and a matching `lnbits` input in `devenv.yaml`. If the user wants lnbits but
  didn't provide a flake, STOP and ask.
- `services.nostr-rs-relay` — free-form `settings` attrset.
- `services.podman-machine`.

### Step 4 — Evaluate

```bash
cd <target-dir>
devenv shell -- true
```

If this fails, show the error verbatim and stop. Do **not** guess-fix Nix.

### Step 5 — (Optional) start services

Only mention if the user picked at least one service:

```bash
devenv up                   # start all processes
devenv processes list
```

## Verification checklist

Before reporting success:

- [ ] `devenv.yaml` has both `upstream-devenv` and `sats-dev` inputs, and
      `sats-dev` is under `imports:`
- [ ] `devenv.nix` has `enable = true;` only for services the user selected
- [ ] `devenv shell -- true` exits 0
- [ ] `devenv.lock` exists
- [ ] If lnbits selected: `lnbits` input present AND `package = …` set

## Reporting

Short summary at the end:
- Path of the created project
- Services enabled
- 2–3 next commands (`devenv up`, `devenv shell`, etc.)

Do NOT dump the generated file contents back unless asked.

## On-demand resources

- `scripts/setup.sh` — invoke via shell; do not read into context unless
  debugging its behavior.
- `references/devenv.yaml.example` — load when you need the yaml template.
- `references/devenv.nix.example` — load when you need the nix template.
