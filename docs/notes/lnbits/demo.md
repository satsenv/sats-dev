# lnbits devenv module

*2026-04-24T13:36:54Z by Showboat 0.6.1*
<!-- showboat-id: 8ab1d718-c0af-4f07-8dd9-1a6499d89d0c -->

Added a devenv module wrapping the lnbits Python venv produced by /home/jfroche/projects/satsenv/lnbits/dev. The module mirrors the NixOS service at nix/modules/lnbits-service.nix: configurable host/port, LNBITS_DATA_FOLDER/LNBITS_EXTENSIONS_PATH env vars, and the same extra env passthrough. Because lnbits resolves lnbits/static relative to the cwd, the startup script cds into the venv's site-packages before exec — matching the NixOS module's WorkingDirectory.

Red phase: wrote tests/lnbits/{devenv.yaml,devenv.nix,.test.sh} first. devenv.yaml adds the lnbits flake as a path input (path:/home/jfroche/projects/satsenv/lnbits/dev). The test enables services.lnbits, passes the flake package, and curls the homepage expecting <title>LNbits</title>. devenv-run-tests confirmed the option does not exist yet.

```bash
cat src/modules/lnbits.nix
```

```output
{ pkgs
, lib
, config
, ...
}:
let
  cfg = config.services.lnbits;
  types = lib.types;
in
{
  options.services.lnbits = {
    enable = lib.mkEnableOption "LNbits, a Lightning wallet and accounts system";

    package = lib.mkOption {
      type = types.package;
      description = ''
        The lnbits package to use. Typically sourced from an external flake
        input (e.g. `inputs.lnbits.packages.''${pkgs.stdenv.hostPlatform.system}.default`).
      '';
    };

    dataDir = lib.mkOption {
      type = types.str;
      default = "${config.devenv.state}/lnbits";
      description = "Directory for LNbits state and extension data.";
    };

    host = lib.mkOption {
      type = types.str;
      default = "127.0.0.1";
      description = "Address to bind the LNbits HTTP server to.";
    };

    port = lib.mkOption {
      type = types.port;
      default = 8231;
      description = "Port for the LNbits HTTP server.";
    };

    env = lib.mkOption {
      type = types.attrsOf types.str;
      default = { };
      example = { LNBITS_ADMIN_UI = "true"; };
      description = ''
        Additional environment variables passed to lnbits.
        See https://github.com/lnbits/lnbits/blob/dev/.env.example for the reference.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    packages = [ cfg.package ];

    env = lib.mkMerge [
      {
        LNBITS_DATA_FOLDER = "${cfg.dataDir}/data";
        LNBITS_EXTENSIONS_PATH = cfg.dataDir;
      }
      cfg.env
    ];

    processes.lnbits = {
      exec = lib.getExe (
        pkgs.writeShellApplication {
          name = "lnbits-start";
          runtimeInputs = [ cfg.package ];
          text = ''
            mkdir -p "${cfg.dataDir}/data"
            # lnbits resolves its static assets and templates relative to the
            # current working directory, so run from the site-packages root
            # of the venv that bundles the `lnbits/` Python package.
            cd "${cfg.package}/lib/python3.12/site-packages"
            exec lnbits --host "${cfg.host}" --port "${toString cfg.port}"
          '';
        }
      );
      ready = {
        exec = ''
          ${lib.getExe pkgs.curl} -sSf "http://${cfg.host}:${toString cfg.port}/" > /dev/null 2>&1
        '';
        period = 2;
        failure_threshold = 60;
      };
      process-compose = {
        readiness_probe = {
          exec = {
            command = pkgs.writeShellScript "is-lnbits-ready" ''
              ${lib.getExe pkgs.curl} -sSf "http://${cfg.host}:${toString cfg.port}/" > /dev/null 2>&1
            '';
          };
          failure_threshold = 60;
          period_seconds = 2;
        };
      };
    };
  };
}
```

```bash
cat tests/lnbits/devenv.yaml tests/lnbits/devenv.nix tests/lnbits/.test.sh
```

```output
inputs:
  upstream-devenv:
    url: github:cachix/devenv?dir=src/modules
  lnbits:
    url: path:/home/jfroche/projects/satsenv/lnbits/dev
    flake: true
{ pkgs, inputs, ... }:
{
  packages = [ pkgs.curl ];

  services.lnbits = {
    enable = true;
    package = inputs.lnbits.packages.${pkgs.stdenv.hostPlatform.system}.default;
    env = {
      LNBITS_ADMIN_UI = "false";
    };
  };
}
#!/usr/bin/env bash
set -e

wait_for_processes

# LNbits serves its index page with a <title>LNbits</title> tag
output=$(curl -sSf http://127.0.0.1:8231/)

if echo "$output" | grep -q "<title>LNbits</title>"; then
  echo "lnbits homepage returned expected <title>LNbits</title>" >&2
else
  echo "Failed to find <title>LNbits</title> in homepage response" >&2
  echo "$output" | head -n 40 >&2
  exit 1
fi

echo "lnbits test passed" >&2
```

First green-phase attempt failed: lnbits started but crashed with 'Directory lnbits/static does not exist' because it resolves static assets relative to the cwd. Matched the NixOS module's WorkingDirectory by adding 'cd ${cfg.package}/lib/python3.12/site-packages' to the startup script. Re-running the test was green.

```bash
pueue log 2691 --lines 6 2>/dev/null | tail -n 6
```

```output
Running tests in 103ms
--------------------------------------------------
✅ [1/1] Passed: lnbits


Ran 1 tests, 0 failed, 0 skipped.
```
