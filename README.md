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

### lnd

Runs `lnd` as a devenv process, wired to an auto-enabled `services.bitcoind`. Exposes read-only `network`, `certFile`, and `macaroonFile` fields so downstream modules can reference the data-dir layout without reproducing it.

```nix
{ ... }:
{
  services.lnd = {
    enable = true;
    # listenAddress = "127.0.0.1";
    # listenPort = 9735;
    # rpcAddress = "127.0.0.1";
    # rpcPort = 10009;
    # restAddress = "127.0.0.1";
    # restPort = 8080;
    # extraConfig = "";
  };
}
```

When enabled, the module sets `LND_CERT_FILE`, `LND_MACAROON_FILE`, and `LND_GRPC_HOST` in the environment.

### clightning

Runs Core Lightning (`lightningd`) as a devenv process, auto-enabling `services.bitcoind` and wiring its RPC credentials. Network is derived from `services.bitcoind.regtest` and exposed read-only as `services.clightning.network`. The RPC socket path is exposed read-only as `services.clightning.rpcFile`.

```nix
{ ... }:
{
  services.clightning = {
    enable = true;
    # address = "127.0.0.1";
    # port = 9735;
    # dataDir = "${config.devenv.state}/clightning";
    # wallet = "sqlite3://.../lightningd.sqlite3";  # postgres://... also supported
    # useBcliPlugin = true;  # set false when using a plugin like trustedcoin
    # extraConfig = "";      # extra lightningd config lines
  };
}
```

### lnbits

Runs [LNbits](https://lnbits.com) as a devenv process. The `package` option must be provided — typically from an external flake input.

```nix
{ pkgs, inputs, ... }:
{
  services.lnbits = {
    enable = true;
    package = inputs.lnbits.packages.${pkgs.stdenv.hostPlatform.system}.default;

    # host = "127.0.0.1";
    # port = 8231;
    # dataDir = "${config.devenv.state}/lnbits";
    # env.LNBITS_ADMIN_UI = "true";

    # Funding source backends — at most one enable = true at a time.
    # backends.lnd.enable = true;   # LndWallet (gRPC), auto-wires services.lnd
  };
}
```

When `backends.lnd.enable` is set, the module auto-enables `services.lnd`, sets `LNBITS_BACKEND_WALLET_CLASS=LndWallet`, and defaults `backends.lnd.{endpoint,port,certFile,macaroonFile}` from `services.lnd`. A tee'd copy of the LNbits process output is written to `services.lnbits.logFile` (`${dataDir}/lnbits.log` by default) for startup introspection.

### nostr-rs-relay

Runs [nostr-rs-relay](https://git.sr.ht/~gheartsfield/nostr-rs-relay) as a devenv process, accepting a free-form `settings` attrset merged into `config.toml`.

```nix
{ ... }:
{
  services.nostr-rs-relay = {
    enable = true;
    # address = "127.0.0.1";
    # port = 8080;
    # settings.info.name = "My relay";
  };
}
```

When enabled, the module sets `NOSTR_RELAY_URL` in the environment.

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
