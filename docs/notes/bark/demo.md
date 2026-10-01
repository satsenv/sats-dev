# Bark (Ark) module: captaind + barkd + CLI

*2026-10-01T21:43:55Z by Showboat 0.6.0*
<!-- showboat-id: bf9d8801-5655-4ecf-b942-38b4ec55bbeb -->

Adds services.bark (CLI), services.bark.server (captaind Ark server, auto-wiring bitcoind+txindex and postgres), and services.bark.barkd (REST wallet daemon). Packages come from the external flake input gitlab:ark-bitcoin/bark (pin bark-0.7.1); enabling without the input throws copy-paste instructions (devenv _mkInputError style, thrown locally). On non-x86_64-linux hosts captaind is built from the pinned source via nix/bark-server.nix (mirrors upstream nix/package-server.nix minus the zig cross machinery) — verified building captaind 0.7.1 on aarch64-darwin. Config follows upstream server/captaind.default.toml, network derived from services.bitcoind.regtest.

```bash
nix build --impure --expr 'let f = builtins.getFlake "github:cachix/devenv"; pkgs = import f.inputs.nixpkgs { system = "aarch64-darwin"; }; bark = builtins.getFlake "gitlab:ark-bitcoin/bark/bark-0.7.1"; in pkgs.callPackage ./nix/bark-server.nix { src = bark.outPath; gitHash = bark.rev or "unknown"; }' -o .scratch-probe/result-bark-server 2>&1 | tail -3; .scratch-probe/result-bark-server/bin/captaind --version
```

```output
captaind 0.7.1-dev+8f5d8c4f4afae87c8e4b3c6fb26fe06e9ae50e6a
```

```bash
grep -E 'captaind admin RPC|ark-info succeeded|barkd /ping|bark test passed|Passed: bark' .scratch-probe/test-bark.log
```

```output
  captaind admin RPC answers
  bark ark-info succeeded
  barkd /ping answered
  bark test passed
• [1/1] Passed: bark (20m26s, closure 2.0 GB)
```

```bash
grep -E 'missing input produces|bark-missing-input test passed' <(devenv-run-tests run tests --only bark-missing-input 2>&1) && echo OK
```

```output
  missing input produces instructions mentioning services.bark and the flake URL
  bark-missing-input test passed
OK
```

```bash
grep -E 'passed +(bark|bitcoind|clightning|lnd|nostr|podman)' .scratch-probe/test-suite.log
```

```output
  passed   bark                   32.5s     2.0 GB
  passed   bark-missing-input      7.0s     1.4 GB
  passed   bitcoind               10.1s     1.5 GB
  passed   clightning             42.6s     1.7 GB
  passed   lnd                    18.0s     1.6 GB
  passed   nostr-rs-relay         11.1s     1.4 GB
  passed   podman                 12.7s     2.6 GB
```
