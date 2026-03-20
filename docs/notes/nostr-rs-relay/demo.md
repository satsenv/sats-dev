# nostr-rs-relay devenv module

*2026-03-20T13:55:02Z by Showboat 0.6.1*
<!-- showboat-id: 9551338b-9d48-44e7-8740-a1b7ecbb200a -->

Red phase: the test correctly fails because the nostr-rs-relay module doesn't exist yet. The error is: The option services.nostr-rs-relay does not exist.

```bash
cat src/modules/nostr-rs-relay.nix
```

```output
{ pkgs
, lib
, config
, ...
}:
let
  cfg = config.services.nostr-rs-relay;
  types = lib.types;
  settingsFormat = pkgs.formats.toml { };

  configFile = settingsFormat.generate "config.toml" (
    lib.recursiveUpdate cfg.settings {
      database.data_directory = cfg.dataDir;
      network = {
        address = cfg.address;
        port = cfg.port;
      };
    }
  );
in
{
  options.services.nostr-rs-relay = {
    enable = lib.mkEnableOption "nostr-rs-relay Nostr relay";

    package = lib.mkOption {
      type = types.package;
      default = pkgs.nostr-rs-relay;
      description = "The nostr-rs-relay package to use.";
    };

    dataDir = lib.mkOption {
      type = types.str;
      default = "${config.devenv.state}/nostr-rs-relay";
      description = "Directory for SQLite database files.";
    };

    address = lib.mkOption {
      type = types.str;
      default = "127.0.0.1";
      description = "Address to listen on.";
    };

    port = lib.mkOption {
      type = types.port;
      default = 8080;
      description = "Port to listen on.";
    };

    settings = lib.mkOption {
      inherit (settingsFormat) type;
      default = { };
      description = "Structured settings merged into config.toml. See https://git.sr.ht/~gheartsfield/nostr-rs-relay/#configuration for documentation.";
    };
  };

  config = lib.mkIf cfg.enable {
    packages = [
      cfg.package
    ];

    processes.nostr-rs-relay = {
      exec = lib.getExe (
        pkgs.writeShellApplication {
          name = "nostr-rs-relay-start";
          runtimeInputs = [ cfg.package ];
          text = ''
            mkdir -p "${cfg.dataDir}"
            exec nostr-rs-relay --config "${configFile}" --db "${cfg.dataDir}"
          '';
        }
      );
      ready = {
        exec = ''
          ${lib.getExe pkgs.curl} -sf -H "Accept: application/nostr+json" "http://${cfg.address}:${toString cfg.port}" > /dev/null 2>&1
        '';
        period = 2;
        failure_threshold = 20;
      };
      process-compose = {
        readiness_probe = {
          exec = {
            command = pkgs.writeShellScript "is-nostr-rs-relay-ready" ''
              ${lib.getExe pkgs.curl} -sf -H "Accept: application/nostr+json" "http://${cfg.address}:${toString cfg.port}" > /dev/null 2>&1
            '';
          };
          failure_threshold = 20;
          period_seconds = 2;
        };
      };
    };

    env.NOSTR_RELAY_URL = "ws://${cfg.address}:${toString cfg.port}";
  };
}
```

The module uses pkgs.formats.toml for structured settings (following the NixOS module pattern), rather than string concatenation used by the bitcoind and lnd modules. The settings option accepts arbitrary TOML configuration that gets merged with the data_directory, address, and port settings. The readiness probe uses curl to check the NIP-11 relay info endpoint.

```bash
cat tests/nostr-rs-relay/devenv.nix
```

```output
{ pkgs, ... }:
{
  packages = [ pkgs.jq ];

  services.nostr-rs-relay = {
    enable = true;
  };
}
```

```bash
cat tests/nostr-rs-relay/.test.sh
```

```output
#!/usr/bin/env bash
set -e

wait_for_processes

# Verify the relay is responding to WebSocket connections
# nostr-rs-relay returns NIP-11 relay info on HTTP GET requests
info=$(curl -sf -H "Accept: application/nostr+json" "http://127.0.0.1:8080")

name=$(echo "$info" | jq -r '.name')
if [ -n "$name" ] && [ "$name" != "null" ]; then
  echo "nostr-rs-relay is running" >&2
  echo "  name: $name" >&2
else
  echo "Failed to get relay info: $info" >&2
  exit 1
fi

echo "nostr-rs-relay test passed" >&2
```

```bash
devenv shell -- devenv-run-tests run --only nostr-rs-relay tests 2>&1 | grep -E '(Running [0-9]|Passed|Ran [0-9]|Starting|nostr-rs-relay|✅)'
```

```output
Running 1 test, 0 skipped
[1/1] Starting: nostr-rs-relay
Initialized empty Git repository in /tmp/devenv-run-tests-nostr-rs-relay6K14uB/.git/
  Running nostr-rs-relay
nostr-rs-relay is running
  name: Unnamed nostr-rs-relay
nostr-rs-relay test passed
✅ [1/1] Passed: nostr-rs-relay
Ran 1 tests, 0 failed, 0 skipped.
```

```bash
devenv shell -- devenv-run-tests run tests 2>&1 | grep -E '(Running [0-9]|Passed|Ran [0-9]|Starting|✅)'
```

```output
Running 5 tests, 0 skipped
[1/5] Starting: bitcoind
✅ [1/5] Passed: bitcoind
[2/5] Starting: bitcoind-process-compose
✅ [2/5] Passed: bitcoind-process-compose
[3/5] Starting: lnd
✅ [3/5] Passed: lnd
[4/5] Starting: nostr-rs-relay
✅ [4/5] Passed: nostr-rs-relay
[5/5] Starting: podman
✅ [5/5] Passed: podman
Ran 5 tests, 0 failed, 0 skipped.
```
