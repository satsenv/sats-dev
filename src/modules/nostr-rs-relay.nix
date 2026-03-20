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
