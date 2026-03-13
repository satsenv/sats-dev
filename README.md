# sats-dev

Custom [devenv](https://devenv.sh) modules for Bitcoin and related services.

## Usage

Add this repository as an input in your project's `devenv.yaml` and import the modules you need.

```yaml
inputs:
  sats-dev:
    url: github:satsenv/sats-dev?dir=src/modules
imports:
  - sats-dev
```

Then use the module options in your `devenv.nix`:

```nix
{ ... }:
{
  services.bitcoind = {
    enable = true;
    regtest = true;
  };
}
```

## Modules

### bitcoind

Runs a `bitcoind` daemon as a devenv process with readiness probes and graceful shutdown.

```nix
{ ... }:
{
  services.bitcoind = {
    enable = true;
    regtest = true;      # Use regtest network (default: false)
    # rpcAddress = "127.0.0.1";
    # rpcPort = 18443;   # Defaults to 18443 in regtest, 8332 otherwise
    # rpcUser = "devenv";
    # rpcPassword = "devenv";
    # extraConfig = "";  # Additional bitcoin.conf lines
  };
}
```

When enabled, the module sets `BITCOIN_RPC_URL` in the environment for convenience.

### podman-machine

Manages a Podman machine lifecycle (init, start, stop) as a devenv process.

```nix
{ ... }:
{
  services.podman-machine = {
    enable = true;
    # machineName = "devenv";
  };
}
```

See [CONTRIBUTING.md](CONTRIBUTING.md) for development setup, testing, and project structure.
