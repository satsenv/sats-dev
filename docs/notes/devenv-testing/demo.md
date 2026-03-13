# Testing devenv modules outside of devenv

*2026-03-13T15:36:21Z by Showboat 0.6.1*
<!-- showboat-id: e7570623-5616-4f7a-9bcf-d98b19790954 -->

This project defines custom devenv modules (like `bitcoind` and `podman-machine`) in `src/modules/`. We use `devenv-run-tests` from the devenv repo to run integration tests defined in `tests/` subdirectories, each containing a `devenv.nix` and a `.test.sh` script.

The key challenge is that `devenv-run-tests` overrides the `devenv` input to point to our `src/modules/top-level.nix`. Our top-level module needs to import upstream devenv's module system, so we introduce a second input called `upstream-devenv` that points to the real devenv modules.

Here is the module entry point that wires upstream devenv with our custom modules:

```bash
cat src/modules/top-level.nix
```

```output
{ inputs, ... }:
{
  imports = [
    "${inputs.upstream-devenv}/top-level.nix"
    ./bitcoind.nix
  ];

  config = {
  };
}
```

Each test directory needs a `devenv.yaml` declaring the `upstream-devenv` input and a `devenv.nix` that uses our custom module options. Here is the podman test setup:

```bash
cat tests/podman/devenv.yaml
```

```output
inputs:
  upstream-devenv:
    url: github:cachix/devenv?dir=src/modules
```

```bash
cat tests/podman/devenv.nix
```

```output
{ ... }:
{
  services.podman-machine.enable = true;
}
```

We also created a new `bitcoind` devenv module with a regtest option, following the pattern from nix-bitcoin. The module provides a process-compose managed daemon with readiness probes and graceful shutdown:

```bash
cat src/modules/bitcoind.nix
```

```output
{ pkgs
, lib
, config
, ...
}:
let
  cfg = config.services.bitcoind;
  types = lib.types;

  configFile = pkgs.writeText "bitcoin.conf" ''
    nodebuglogfile=1
    logtimestamps=1
    server=1
    ${lib.optionalString cfg.regtest ''
      regtest=1
      [regtest]
    ''}
    rpcbind=${cfg.rpcAddress}
    rpcport=${toString cfg.rpcPort}
    rpcallowip=${cfg.rpcAddress}
    rpcuser=${cfg.rpcUser}
    rpcpassword=${cfg.rpcPassword}
    ${cfg.extraConfig}
  '';
in
{
  options.services.bitcoind = {
    enable = lib.mkEnableOption "Bitcoin daemon";

    package = lib.mkOption {
      type = types.package;
      default = pkgs.bitcoind;
      description = "The bitcoind package to use.";
    };

    regtest = lib.mkOption {
      type = types.bool;
      default = false;
      description = "Enable regtest mode.";
    };

    dataDir = lib.mkOption {
      type = types.str;
      default = "${config.devenv.state}/bitcoind";
      description = "Data directory for bitcoind.";
    };

    rpcAddress = lib.mkOption {
      type = types.str;
      default = "127.0.0.1";
      description = "Address for the RPC server to bind to.";
    };

    rpcPort = lib.mkOption {
      type = types.port;
      default = if cfg.regtest then 18443 else 8332;
      description = "Port for the RPC server.";
    };

    rpcUser = lib.mkOption {
      type = types.str;
      default = "devenv";
      description = "RPC username.";
    };

    rpcPassword = lib.mkOption {
      type = types.str;
      default = "devenv";
      description = "RPC password.";
    };

    extraConfig = lib.mkOption {
      type = types.lines;
      default = "";
      description = "Extra lines appended to bitcoin.conf.";
    };
  };

  config = lib.mkIf cfg.enable {
    packages = [
      cfg.package
    ];

    processes.bitcoind = {
      exec = lib.getExe (
        pkgs.writeShellApplication {
          name = "bitcoind-start";
          runtimeInputs = [ cfg.package ];
          text = ''
            mkdir -p "${cfg.dataDir}"
            exec bitcoind -datadir="${cfg.dataDir}" -conf="${configFile}"
          '';
        }
      );
      process-compose = {
        readiness_probe = {
          exec = {
            command = pkgs.writeShellScript "is-bitcoind-ready" ''
              ${lib.getExe' cfg.package "bitcoin-cli"} \
                -datadir="${cfg.dataDir}" \
                -rpcuser="${cfg.rpcUser}" \
                -rpcpassword="${cfg.rpcPassword}" \
                ${lib.optionalString cfg.regtest "-regtest"} \
                getblockchaininfo > /dev/null 2>&1
            '';
          };
          failure_threshold = 20;
          period_seconds = 2;
        };
        shutdown = {
          command = ''
            ${lib.getExe' cfg.package "bitcoin-cli"} \
              -datadir="${cfg.dataDir}" \
              -rpcuser="${cfg.rpcUser}" \
              -rpcpassword="${cfg.rpcPassword}" \
              ${lib.optionalString cfg.regtest "-regtest"} \
              stop
          '';
          timeout_seconds = 30;
        };
      };
    };

    env.BITCOIN_RPC_URL = "http://${cfg.rpcUser}:${cfg.rpcPassword}@${cfg.rpcAddress}:${toString cfg.rpcPort}";
  };
}
```

Running the test suite with `devenv-run-tests` discovers test subdirectories, copies each to a temp dir, overrides the `devenv` input to our `src/modules`, and executes `.test.sh` inside the devenv shell:

```bash
find src tests -type f | sort
```

```output
src/modules/bitcoind.nix
src/modules/flake.nix
src/modules/podman.nix
src/modules/top-level.nix
tests/podman/devenv.nix
tests/podman/devenv.yaml
tests/podman/.test.sh
```

Note: `top-level.nix` must import all custom modules that tests rely on. The `devenv-run-tests` runner calls `devenv test` for each test directory, which starts services and runs `.test.sh` in the devenv shell.

We added podman.nix back to top-level.nix (it was missing) and created a bitcoind test that verifies regtest mode starts and can generate blocks:

```bash
cat src/modules/top-level.nix
```

```output
{ inputs, ... }:
{
  imports = [
    "${inputs.upstream-devenv}/top-level.nix"
    ./bitcoind.nix
    ./podman.nix
  ];

  config = {
  };
}
```

```bash
cat tests/bitcoind/devenv.nix
```

```output
{ ... }:
{
  services.bitcoind = {
    enable = true;
    regtest = true;
  };
}
```

```bash
cat tests/bitcoind/.test.sh
```

```output
set -e

# Verify bitcoind is running in regtest mode
info=$(bitcoin-cli -regtest -rpcuser=devenv -rpcpassword=devenv getblockchaininfo)
chain=$(echo "$info" | grep -o '"chain":"[^"]*"' | head -1)

if echo "$chain" | grep -q "regtest"; then
  echo "bitcoind regtest is running"
else
  echo "Expected regtest chain, got: $chain"
  exit 1
fi

# Generate a block to confirm the node is functional
bitcoin-cli -regtest -rpcuser=devenv -rpcpassword=devenv createwallet "test" 2>/dev/null || true
address=$(bitcoin-cli -regtest -rpcuser=devenv -rpcpassword=devenv getnewaddress)
bitcoin-cli -regtest -rpcuser=devenv -rpcpassword=devenv generatetoaddress 1 "$address"

count=$(bitcoin-cli -regtest -rpcuser=devenv -rpcpassword=devenv getblockcount)
if [ "$count" -ge 1 ]; then
  echo "Block generation works, count: $count"
else
  echo "Expected block count >= 1, got: $count"
  exit 1
fi

echo "bitcoind regtest test passed"
```

Now we run both the podman and bitcoind tests together. We use `--only bitcoind` to run just the bitcoind test first since the podman test requires a running podman machine:

We created a bitcoind integration test. The test enables regtest mode, waits for the process to be ready, verifies the chain is `regtest`, creates a wallet, and generates a block:

```bash
cat tests/bitcoind/devenv.nix
```

```output
{ pkgs, ... }:
{
  packages = [ pkgs.jq ];

  services.bitcoind = {
    enable = true;
    regtest = true;
  };
}
```

```bash
cat tests/bitcoind/.test.sh
```

```output
set -e

CLI="bitcoin-cli -regtest -rpcuser=devenv -rpcpassword=devenv"

wait_for_processes

# Verify bitcoind is running in regtest mode
chain=$($CLI getblockchaininfo | jq -r '.chain')
if [ "$chain" = "regtest" ]; then
  echo "bitcoind regtest is running"
else
  echo "Expected regtest chain, got: $chain"
  exit 1
fi

# Generate a block to confirm the node is functional
$CLI createwallet "test" 2>/dev/null || true
address=$($CLI getnewaddress)
$CLI generatetoaddress 1 "$address" > /dev/null

count=$($CLI getblockcount)
if [ "$count" -ge 1 ]; then
  echo "Block generation works, count: $count"
else
  echo "Expected block count >= 1, got: $count"
  exit 1
fi

echo "bitcoind regtest test passed"
```

Key findings during implementation: the devenv native process manager requires a `ready` option on the process definition (using the `lib/ready.nix` submodule type) for `wait_for_processes` to block. The `process-compose` readiness probe alone is not sufficient since `devenv test` uses the native manager. The module defines both for compatibility. Also, `devenv test` provides `wait_for_processes` as an exported shell function in the test environment, which should be called at the start of any test that depends on running processes.

Running the full test suite:

```bash
devenv-run-tests run --only bitcoind tests 2>&1
```

```output
Running 1 test, 0 skipped

[1/1] Starting: bitcoind
--------------------------------------------------
Initialized empty Git repository in /tmp/devenv-run-tests-bitcoindmG4yqD/.git/
  Running bitcoind
Configuring shell
Configuring shell in 11.9s
Building tests
Building tests in 395ms
Loading tasks
Loading tasks in 672ms
Running tasks     devenv:enterShell

Running tasks
Running           devenv:files:cleanup
Succeeded         devenv:files:cleanup (2.88ms)
Running           devenv:enterShell
Succeeded         devenv:enterShell (31.75ms)
Running           devenv:enterTest
No command        devenv:enterTest
Running tasks in 34.8ms
1 Skipped, 2 Succeeded
Running processes
Running processes in 2.03s
Running tests
• Waiting for native processes to be ready (timeout: 120 seconds)...
✓ All processes are ready
Running tests in 341ms
--------------------------------------------------
✅ [1/1] Passed: bitcoind


Ran 1 tests, 0 failed, 0 skipped.
```

We added a second bitcoind test using process-compose as the process manager. The only difference is `process.manager.implementation = "process-compose"` in `devenv.nix`, which exercises the `process-compose` readiness probe path instead of the native one:

```bash
cat tests/bitcoind-process-compose/devenv.nix
```

```output
{ pkgs, ... }:
{
  packages = [ pkgs.jq ];

  process.manager.implementation = "process-compose";

  services.bitcoind = {
    enable = true;
    regtest = true;
  };
}
```

```bash
devenv-run-tests run --only bitcoind-process-compose tests 2>&1 | grep -E '(Running [0-9]|Passed|Ran [0-9]|Starting|✅|✓)'
```

```output
Running 1 test, 0 skipped
[1/1] Starting: bitcoind-process-compose
✓ All processes are ready
✅ [1/1] Passed: bitcoind-process-compose
Ran 1 tests, 0 failed, 0 skipped.
```

To see echo output from test scripts, write to stderr (`>&2`). Devenv's tracing layer filters out stdout in non-verbose mode but surfaces stderr. This applies to both the native and process-compose process managers.

```bash
devenv-run-tests run --only bitcoind tests 2>&1 | grep -E '(Running [0-9]|Passed|Ran [0-9]|Starting|✅|✓|bitcoind regtest|Block generation|test passed)'
```

```output
Running 1 test, 0 skipped
[1/1] Starting: bitcoind
✓ All processes are ready
bitcoind regtest is running
Block generation works, count: 8
bitcoind regtest test passed
✅ [1/1] Passed: bitcoind
Ran 1 tests, 0 failed, 0 skipped.
```
