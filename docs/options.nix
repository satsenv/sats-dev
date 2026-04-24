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
    };
  };

  eval = lib.evalModules {
    modules = [
      { _module.args = { inherit pkgs; }; }
      devenvStub
      ../src/modules/bitcoind.nix
      ../src/modules/clightning.nix
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
