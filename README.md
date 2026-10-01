# sats-dev

Custom [devenv](https://devenv.sh) modules for Bitcoin and related services.

## Usage

> 💡 **Prefer an AI-assisted bootstrap?** This repo ships with a goose skill
> at [`skills/sats-dev-init/`](skills/sats-dev-init/) that scaffolds a working `devenv.yaml` +
> `devenv.nix` for you. See [`docs/src/guides/ai-skill.md`](docs/src/guides/ai-skill.md).

Add this repository as an input in your project's `devenv.yaml`, along with the
required `upstream-devenv` input. Also add the `imports` section:

```yaml
inputs:
  upstream-devenv:
    url: github:cachix/devenv?dir=src/modules
  sats-dev:
    url: github:satsenv/sats-dev?dir=src/modules
imports:
  - sats-dev
```

Notes:

- `upstream-devenv` is required — the sats-dev modules import options from it. Omitting it produces `error: attribute 'upstream-devenv' missing`.
- For local development against a checkout, replace the `sats-dev` URL with `path:/absolute/path/to/sats-dev?dir=src/modules`.

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

### bark

Ark (by [Second](https://second.tech)) tooling: the `bark` wallet CLI, the `barkd` REST wallet daemon, and `captaind`, the Ark server (ASP).

Packages come from the external flake input `gitlab:ark-bitcoin/bark`, declared in your `devenv.yaml`:

```yaml
inputs:
  bark:
    url: gitlab:ark-bitcoin/bark/bark-0.7.1
    flake: true
```

Enabling any `services.bark.*` component without that input fails evaluation with these same instructions (unless you set the corresponding `package` option explicitly).

```nix
{ pkgs, inputs, ... }:
{
  services.bitcoind.regtest = true;  # the bark network is derived from this

  services.bark = {
    enable = true;                   # bark CLI (+ barkd) in the shell
    package = inputs.bark.packages.${pkgs.stdenv.hostPlatform.system}.bark;

    server.enable = true;            # captaind, the Ark server
    barkd.enable = true;             # REST wallet daemon on 127.0.0.1:3000
  };
}
```

- `services.bark.server` runs `captaind` as a devenv process. On first start it initializes the server wallet and database (`captaind create`), then serves via `captaind start` (which self-migrates the schema). It auto-enables `services.bitcoind` (injecting `txindex=1`) and `services.postgres` (loopback TCP plus a `bark-server-db` database owned by a `bark` role — both overridable under `services.bark.server.postgres`).
- The generated captaind config follows upstream's `captaind.default.toml` values, wired to the sats-dev bitcoind and postgres settings. Ports: public Ark gRPC `3535`, admin gRPC `3536` (unauthenticated, loopback only), integration gRPC `3537`.
- captaind comes prebuilt from the bark flake on x86_64-linux; on other hosts (e.g. aarch64-darwin) it is built from the pinned source, which takes a while on first build. Note the `bark.cachix.org` cache currently ships no darwin artifacts for bark-0.7.1 either, so on macOS the `bark` CLI package is likewise a lengthy one-time source build.
- `services.bark.barkd` binds loopback behind a bearer token by default — print it with `barkd --datadir "$DEVENV_STATE/barkd" secret show` — or set `services.bark.barkd.noAuth = true`.

When the server is enabled the environment gets `BARK_ASP_URL` (public Ark gRPC) and `BARK_ADMIN_RPC_ADDR`; barkd sets `BARKD_URL`.

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
