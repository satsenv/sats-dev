# Bootstrapping with an AI assistant

sats-dev ships with a [goose](https://block.github.io/goose/) **skill** that lets
an AI assistant scaffold a working devenv project for you in a few seconds.

The skill lives in the repository under:

```
skills/sats-dev-init/
├── SKILL.md
├── references/
│   ├── devenv.yaml.example
│   └── devenv.nix.example
└── scripts/
    └── setup.sh
```

It is a self-contained set of instructions the agent follows to:

1. Run `devenv init` in a target directory (if not already a devenv project).
2. Write a `devenv.yaml` with the required `upstream-devenv` and `sats-dev`
   inputs and the `sats-dev` import.
3. Write a `devenv.nix` enabling only the services you asked for
   (`bitcoind`, `lnd`, `clightning`, `lnbits`, `nostr-rs-relay`,
   `podman-machine`).
4. Verify the result with `devenv shell -- true` and (optionally)
   `devenv up`.

## Prerequisites

- [`devenv`](https://devenv.sh/getting-started/) on your `PATH`
- [Nix](https://nixos.org/download) with flakes enabled
- A goose-compatible AI agent — the reference client is
  [goose](https://block.github.io/goose/docs/quickstart)

## Loading the skill

Skills are discovered from two locations:

| Scope   | Path                                   | When to use                          |
|---------|----------------------------------------|--------------------------------------|
| Project | `<repo>/skills/`                       | Cloned this repo, working inside it  |
| Global  | `~/.agents/skills/`                    | Available from any working directory |

### Option A — Install with `npx skills` (recommended)

Fetch and install the skill straight from the `satsenv/sats-dev` repository
using the `skills` CLI (no clone required):

```bash
nix shell nixpkgs#nodejs -c npx skills add satsenv/sats-dev
```

The command runs interactively and prompts you to choose the install scope:

- **Project** — installs into `<repo>/skills/`, available only inside the
  current project.
- **Global** — installs into `~/.agents/skills/`, available from any working
  directory.

For non-interactive use (e.g. in CI or scripts), pass the scope explicitly:

```bash
# Force project-level install
nix shell nixpkgs#nodejs -c npx skills add satsenv/sats-dev --project

# Force global install
nix shell nixpkgs#nodejs -c npx skills add satsenv/sats-dev --global
```

### Option B — Use it from a clone of this repo

```bash
git clone https://github.com/satsenv/sats-dev.git
cd sats-dev
goose session
```

Goose will automatically pick up `skills/sats-dev-init` and list it in
its available skills at session start.

### Option C — Install it globally by hand

If you already have a clone and prefer to copy the files yourself:

```bash
mkdir -p ~/.agents/skills
cp -r /path/to/sats-dev/skills/sats-dev-init ~/.agents/skills/
```

### Verifying the skill is loaded

Inside a goose session:

```
> what skills do you have?
```

You should see `sats-dev-init` listed with its description.

## Using the skill

Just ask the agent in natural language. Goose will call
`load_skill(name: "sats-dev-init")` to read the full instructions before acting.

### Examples

Minimal — accept defaults (bitcoind + lnd on regtest, current directory):

```
Use the sats-dev-init skill to set up a devenv here.
```

Pick a directory and services:

```
Use sats-dev-init to bootstrap ~/projects/my-ln-app with bitcoind, lnd, and clightning on regtest.
```

Full stack including LNbits (requires an additional `lnbits` flake input —
the skill will prompt you for the URL):

```
Use sats-dev-init in ./demo with bitcoind + lnd + lnbits, regtest.
```

### What the skill will ask

The skill's first step is to gather:

- **Target directory** (default: current working directory)
- **Services** to enable — any subset of the six sats-dev modules
- **Network** — `regtest` (default) or mainnet
- **sats-dev source** — the default `github:satsenv/sats-dev?dir=src/modules`
  is fine for most users; override with a local path for development
  (`path:/absolute/path/to/sats-dev/src/modules`)

Provide the answers up-front to skip the prompts:

```
Use sats-dev-init in /tmp/demo with services bitcoind and lnd, regtest, default source.
```

## After bootstrap

Once the skill finishes, standard devenv commands apply:

```bash
cd <your project>
devenv shell     # enter the shell
devenv up        # start all enabled services
```

See the [Module options reference](../reference/options.md) for every option
you can further tweak in `devenv.nix`.

## Troubleshooting

**`error: attribute 'upstream-devenv' missing`**
The generated `devenv.yaml` must declare an `upstream-devenv` input alongside
`sats-dev`. The skill templates handle this, but if you edited the file by
hand, re-add:

```yaml
inputs:
  upstream-devenv:
    url: github:cachix/devenv
  sats-dev:
    url: github:satsenv/sats-dev?dir=src/modules
```

**`services.lnbits` fails to evaluate**
LNbits requires a real `lnbits` flake input. Uncomment the `lnbits` block in
`devenv.yaml` (the templates include a placeholder) and point it at your
lnbits source.

**Skill not showing up in goose**
Confirm the directory layout is exactly
`<scope>/skills/sats-dev-init/SKILL.md` (project) or
`~/.agents/skills/sats-dev-init/SKILL.md` (global) and that the file has valid
YAML frontmatter (`name:` and `description:`). Restart the goose session
after adding a new skill.
