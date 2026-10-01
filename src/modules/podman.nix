{ pkgs
, lib
, config
, ...
}:
let
  cfg = config.services.podman-machine;
  types = lib.types;
  # podman resolves machine helpers (gvproxy, virtiofsd) via
  # helper_binaries_dir — PATH is not searched. The nixpkgs podman
  # wrapper pre-populates its own libexec only on darwin, so on Linux we
  # point podman at the helpers ourselves.
  podmanMachineHelpers = pkgs.symlinkJoin {
    name = "podman-machine-helpers";
    paths = [
      pkgs.gvproxy
      pkgs.virtiofsd
    ];
  };
in
{
  options.services.podman-machine = {
    enable = lib.mkEnableOption "Podman Machine";

    machineName = lib.mkOption {
      default = "devenv";
      type = types.str;
      description = "Name of the machine to start.";
    };
  };

  config = lib.mkIf cfg.enable {
    env = {
      CONTAINER_CONNECTION = "${cfg.machineName}";
    }
    // lib.optionalAttrs pkgs.stdenv.isLinux {
      CONTAINERS_CONF = "${pkgs.writeText "containers.conf" ''
        [engine]
        helper_binaries_dir = ["${podmanMachineHelpers}/bin"]
      ''}";
    };
    packages = [
      pkgs.podman
      pkgs.qemu
    ]
    ++ (lib.optionals pkgs.stdenv.isLinux [
      pkgs.virtiofsd
    ])
    ++ (lib.optionals pkgs.stdenv.isDarwin [
      pkgs.vfkit
    ]);

    tasks."podman-machine:init" = {
      exec = lib.getExe (
        pkgs.writeShellApplication {
          name = "podman-machine-init";
          runtimeInputs = [
            pkgs.podman
            pkgs.jq
          ];
          text = ''
            if podman machine list --format json | jq 'any(.[] | (.Name == "${cfg.machineName}"); .)' -e -r > /dev/null; then
              echo "Podman machine '${cfg.machineName}' already exists."
              echo ""
              exit 0
            fi
            echo "Creating podman machine '${cfg.machineName}'..."
            echo ""
            podman machine init --rootful ${cfg.machineName}
            # disable selinux
            # TODO move to specific task for dagger
            podman machine start ${cfg.machineName}
            podman machine ssh ${cfg.machineName} sed -i --follow-symlinks 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/sysconfig/selinux 
            podman machine stop ${cfg.machineName}
            podman machine start ${cfg.machineName}
            podman machine ssh ${cfg.machineName} sestatus | grep disabled
            podman machine stop ${cfg.machineName}
          '';
        }
      );
      before = [
        "devenv:enterShell"
        "devenv:enterTest"
      ];
    };

    scripts."podman-machine-stop" = {
      exec = lib.getExe (
        pkgs.writeShellApplication {
          name = "podman-machine-stop";
          runtimeInputs = [
            pkgs.podman
            pkgs.jq
          ];
          text = ''
            if podman machine list --format json | jq 'any(.[] | (.Name == "${cfg.machineName}" and .Running == true); .)' -e -r > /dev/null; then
              podman machine stop ${cfg.machineName}
            fi
          '';
        }
      );
    };

    processes.podman-machine = {
      exec = lib.getExe (
        pkgs.writeShellApplication {
          name = "podman-machine-start";
          runtimeInputs = [
            pkgs.podman
            pkgs.jq
          ]
          ++ (lib.optionals pkgs.stdenv.isDarwin [
            pkgs.vfkit
          ]);

          text = ''
            if podman machine list --format json | jq 'any(.[] | (.Name == "${cfg.machineName}" and .Running == true); .)' -e -r > /dev/null; then
              echo "Podman machine '${cfg.machineName}' is running."
              echo ""
              exit 0
            fi
            echo "Starting podman machine '${cfg.machineName}'..."
            echo ""
            podman machine start ${cfg.machineName}
          '';
        }
      );
    };
  };
}
