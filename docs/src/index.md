# sats-dev

Custom [devenv](https://devenv.sh) modules for Bitcoin and related services.

## Available modules

- **bitcoind** — Bitcoin daemon with regtest support and ZMQ pub/sub
- **lnd** — Lightning Network daemon, automatically configures bitcoind with ZMQ
- **nostr-rs-relay** — Nostr relay with structured TOML settings
- **podman-machine** — Podman machine lifecycle management

## Usage

Add sats-dev as an input in your project's `devenv.yaml`:

```yaml
inputs:
  sats-dev:
    url: github:owner/sats-dev?dir=src/modules
imports:
  - sats-dev
```

Then enable the services you need in `devenv.nix`:

```nix
{ pkgs, ... }:
{
  services.bitcoind = {
    enable = true;
    regtest = true;
  };

  services.lnd.enable = true;
}
```
