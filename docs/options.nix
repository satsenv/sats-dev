{ pkgs ? import <nixpkgs> { }
}:
let
  lib = pkgs.lib;

  # Minimal stubs for devenv options that our modules reference.
  devenvStub = { config, ... }: {
    options = {
      devenv.state = lib.mkOption {
        type = lib.types.str;
        default = "/tmp/devenv-state";
      };

      packages = lib.mkOption {
        type = lib.types.listOf lib.types.package;
        default = [ ];
      };

      env = lib.mkOption {
        type = lib.types.submodule {
          freeformType = lib.types.lazyAttrsOf lib.types.anything;
        };
        default = { };
      };

      processes = lib.mkOption {
        type = lib.types.attrsOf (lib.types.submodule {
          freeformType = lib.types.lazyAttrsOf lib.types.anything;
          options = {
            exec = lib.mkOption {
              type = lib.types.str;
              description = "Bash code to run the process.";
            };
            after = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [ ];
              description = "Processes that must be ready before this one starts.";
            };
            ready = lib.mkOption {
              type = lib.types.submodule {
                freeformType = lib.types.lazyAttrsOf lib.types.anything;
              };
              default = { };
              description = "Readiness probe configuration.";
            };
            process-compose = lib.mkOption {
              type = lib.types.submodule {
                freeformType = lib.types.lazyAttrsOf lib.types.anything;
              };
              default = { };
              description = "Process-compose specific configuration.";
            };
          };
        });
        default = { };
      };

      tasks = lib.mkOption {
        type = lib.types.attrsOf lib.types.anything;
        default = { };
      };

      scripts = lib.mkOption {
        type = lib.types.attrsOf lib.types.anything;
        default = { };
      };

      # Modules may attach assertions/warnings; devenv declares these,
      # so stub them here. Config written against an undeclared option
      # fails this eval even when the module is disabled.
      assertions = lib.mkOption {
        type = lib.types.listOf lib.types.anything;
        default = [ ];
      };

      warnings = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
      };

      # Stub for devenv's postgres module, which bark.nix writes
      # (services.postgres.enable/listen_addresses/initialDatabases).
      # Freeform so any attribute is accepted; internal so the stub
      # itself is never rendered into the published options page.
      services.postgres = lib.mkOption {
        type = lib.types.submodule {
          freeformType = lib.types.lazyAttrsOf lib.types.anything;
        };
        default = { };
        internal = true;
        visible = false;
      };
    };
  };

  eval = lib.evalModules {
    modules = [
      { _module.args = { inherit pkgs; }; }
      devenvStub
      # Service modules rendered into the options page. When you add
      # src/modules/<name>.nix, register it here — the list is explicit
      # because infra modules (top-level/devenv/flake) are not services.
      ../src/modules/bark.nix
      ../src/modules/bitcoind.nix
      ../src/modules/clightning.nix
      ../src/modules/lnbits.nix
      ../src/modules/lnd.nix
      ../src/modules/nostr-rs-relay.nix
      ../src/modules/podman.nix
    ];
  };

  filteredOptions = lib.filterAttrs (name: _: name == "services") eval.options;

  doc = pkgs.nixosOptionsDoc {
    options = filteredOptions;
    documentType = "none";
    warningsAreErrors = false;
    transformOptions = opt: opt // {
      declarations = [ ];
      default = if opt ? default && opt.default ? text then
        opt.default // {
          text = builtins.replaceStrings
            [ "/tmp/devenv-state" ]
            [ "\${devenv.state}" ]
            opt.default.text;
        }
      else
        opt.default or { };
    };
  };
in
doc.optionsCommonMark
