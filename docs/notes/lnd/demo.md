# LND devenv module

*2026-03-13T17:25:15Z by Showboat 0.6.1*
<!-- showboat-id: 52852d5f-ccf3-407e-abd7-ead71284d95a -->

A minimal LND (Lightning Network Daemon) devenv module inspired by nix-bitcoin's lnd.nix. The module provides a development-friendly lnd process that connects to bitcoind with ZMQ block/tx notifications, uses noseedbackup and no-macaroons for simplified dev workflows, and stores TLS certs in the data directory. As part of this work, the bitcoind module was enhanced with a zmq option group including readiness probes for ZMQ port availability.

The bitcoind module now has a zmq option group with enable, pubrawblock, and pubrawtx. When zmq.enable is true, the readiness probe checks both RPC availability and ZMQ port connectivity using netcat. The lnd module sets zmq.enable = true by default.

```bash
cat src/modules/lnd.nix
```

```output
{ pkgs
, lib
, config
, ...
}:
let
  cfg = config.services.lnd;
  bitcoind = config.services.bitcoind;
  types = lib.types;

  network = if bitcoind.regtest then "regtest" else "mainnet";

  lncliCmd = ''
    ${lib.getExe' cfg.package "lncli"} \
      --network ${network} \
      --rpcserver=${cfg.rpcAddress}:${toString cfg.rpcPort} \
      --lnddir="${cfg.dataDir}" \
      --tlscertpath="${cfg.dataDir}/tls.cert" \
      --no-macaroons'';


  configFile = pkgs.writeText "lnd.conf" (''
    datadir=${cfg.dataDir}
    tlscertpath=${cfg.dataDir}/tls.cert
    tlskeypath=${cfg.dataDir}/tls.key
    noseedbackup=1
    no-macaroons=1

    listen=${cfg.listenAddress}:${toString cfg.listenPort}
    rpclisten=${cfg.rpcAddress}:${toString cfg.rpcPort}
    restlisten=${cfg.restAddress}:${toString cfg.restPort}

    debuglevel=info

    bitcoin.active=1
    bitcoin.node=bitcoind
  '' + lib.optionalString bitcoind.regtest ''
    bitcoin.regtest=1
  '' + ''

    bitcoind.rpchost=${bitcoind.rpcAddress}:${toString bitcoind.rpcPort}
    bitcoind.rpcuser=${bitcoind.rpcUser}
    bitcoind.rpcpass=${bitcoind.rpcPassword}
    bitcoind.zmqpubrawblock=${bitcoind.zmq.pubrawblock}
    bitcoind.zmqpubrawtx=${bitcoind.zmq.pubrawtx}
  '' + cfg.extraConfig);
in
{
  options.services.lnd = {
    enable = lib.mkEnableOption "Lightning Network daemon";

    package = lib.mkOption {
      type = types.package;
      default = pkgs.lnd;
      description = "The lnd package to use.";
    };

    dataDir = lib.mkOption {
      type = types.str;
      default = "${config.devenv.state}/lnd";
      description = "Data directory for lnd.";
    };

    listenAddress = lib.mkOption {
      type = types.str;
      default = "127.0.0.1";
      description = "Address to listen for peer connections.";
    };

    listenPort = lib.mkOption {
      type = types.port;
      default = 9735;
      description = "Port to listen for peer connections.";
    };

    rpcAddress = lib.mkOption {
      type = types.str;
      default = "127.0.0.1";
      description = "Address to listen for gRPC connections.";
    };

    rpcPort = lib.mkOption {
      type = types.port;
      default = 10009;
      description = "Port to listen for gRPC connections.";
    };

    restAddress = lib.mkOption {
      type = types.str;
      default = "127.0.0.1";
      description = "Address to listen for REST connections.";
    };

    restPort = lib.mkOption {
      type = types.port;
      default = 8080;
      description = "Port to listen for REST connections.";
    };

    extraConfig = lib.mkOption {
      type = types.lines;
      default = "";
      description = "Extra lines appended to lnd.conf.";
    };
  };

  config = lib.mkIf cfg.enable {
    services.bitcoind = {
      enable = true;
      zmq.enable = lib.mkDefault true;
    };

    packages = [
      cfg.package
    ];

    processes.lnd = {
      after = [ "devenv:processes:bitcoind" ];
      exec = lib.getExe (
        pkgs.writeShellApplication {
          name = "lnd-start";
          runtimeInputs = [ cfg.package ];
          text = ''
            mkdir -p "${cfg.dataDir}"
            exec lnd --configfile="${configFile}"
          '';
        }
      );
      ready = {
        exec = ''
          ${lncliCmd} getinfo > /dev/null 2>&1
        '';
        period = 2;
        failure_threshold = 30;
      };
      process-compose = {
        readiness_probe = {
          exec = {
            command = pkgs.writeShellScript "is-lnd-ready" ''
              ${lncliCmd} getinfo > /dev/null 2>&1
            '';
          };
          failure_threshold = 30;
          period_seconds = 2;
        };
        depends_on.bitcoind.condition = "process_healthy";
        shutdown = {
          command = ''
            ${lncliCmd} stop
          '';
          timeout_seconds = 30;
        };
      };
    };
  };
}
```

Key design decisions: the lnd process uses after = [ devenv:processes:bitcoind ] to ensure bitcoind is ready before lnd starts. The lnd module automatically enables bitcoind.zmq, and the bitcoind readiness probe verifies ZMQ ports are listening alongside RPC. This prevents lnd from crashing on startup due to unavailable ZMQ endpoints.

The test generates a block on the regtest chain before checking lnd sync status, since lnd reports synced_to_chain=false on an empty chain with 0 blocks.

```bash
cat tests/lnd/devenv.nix
```

```output
{ pkgs, ... }:
{
  packages = [ pkgs.jq ];

  services.bitcoind = {
    enable = true;
    regtest = true;
  };

  services.lnd = {
    enable = true;
  };
}
```

```bash
cat tests/lnd/.test.sh
```

```output
#!/usr/bin/env bash
set -e

CLI="bitcoin-cli -regtest -rpcuser=devenv -rpcpassword=devenv"
LNCLI="lncli --network regtest --rpcserver=127.0.0.1:10009 --lnddir=$DEVENV_STATE/lnd --tlscertpath=$DEVENV_STATE/lnd/tls.cert --no-macaroons"

wait_for_processes

# Generate a block so lnd has something to sync to
$CLI createwallet "test" 2>/dev/null || true
address=$($CLI -rpcwallet=test getnewaddress)
$CLI generatetoaddress 1 "$address" > /dev/null

# Verify lnd is running and connected to bitcoind
info=$($LNCLI getinfo 2>&1)
if echo "$info" | jq -e '.identity_pubkey' > /dev/null 2>&1; then
  echo "lnd is running" >&2
  echo "  pubkey: $(echo "$info" | jq -r '.identity_pubkey')" >&2
else
  echo "Failed to get lnd info: $info" >&2
  exit 1
fi

# Verify lnd is synced to chain
synced=$(echo "$info" | jq -r '.synced_to_chain')
block_height=$(echo "$info" | jq -r '.block_height')
if [ "$synced" = "true" ]; then
  echo "lnd is synced to chain at height $block_height" >&2
else
  echo "lnd is not synced (synced=$synced height=$block_height)" >&2
  echo "$info" | jq '{synced_to_chain, synced_to_graph, block_height, block_hash}' >&2
  exit 1
fi

echo "lnd test passed" >&2
```

```bash
devenv-run-tests run --only lnd tests 2>&1 | grep -E '(Running [0-9]|Passed|Ran [0-9]|Starting|lnd is|lnd test|pubkey|synced|height)'
```

```output
Running 1 test, 0 skipped
[1/1] Starting: lnd
lnd is running
  pubkey: 0232255e473b07373f488969b27a36901a361e9795df6242b54a52ce45b5a45b53
lnd is synced to chain at height 1
lnd test passed
✅ [1/1] Passed: lnd
Ran 1 tests, 0 failed, 0 skipped.
```

The full test suite (bitcoind, bitcoind-process-compose, lnd, podman) passes with all 4 tests green.

```bash
devenv-run-tests run tests 2>&1 | grep -E '(Running [0-9]|Passed|Ran [0-9]|Starting|✅)'
```

```output
Running 4 tests, 0 skipped
[1/4] Starting: bitcoind
✅ [1/4] Passed: bitcoind
[2/4] Starting: bitcoind-process-compose
✅ [2/4] Passed: bitcoind-process-compose
[3/4] Starting: lnd
✅ [3/4] Passed: lnd
[4/4] Starting: podman
✅ [4/4] Passed: podman
Ran 4 tests, 0 failed, 0 skipped.
```
