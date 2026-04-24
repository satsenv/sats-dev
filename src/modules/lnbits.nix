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
      # lnbits/app.py mounts StaticFiles with the relative path
      # Path("lnbits", "static"), so the server's cwd must contain the
      # `lnbits/` package or startup fails at import.
      cwd = "${cfg.package}/lib/python3.12/site-packages";
      exec = lib.getExe (
        pkgs.writeShellApplication {
          name = "lnbits-start";
          runtimeInputs = [ cfg.package ];
          text = ''
            mkdir -p "${cfg.dataDir}/data"
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
        # devenv's process-compose backend does not forward the top-level
        # `cwd`, so set process-compose's own `working_dir` via the escape
        # hatch for parity with the native/mprocs backends.
        working_dir = "${cfg.package}/lib/python3.12/site-packages";
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
