{ pkgs
, lib
, config
, ...
}:
let
  cfg = config.services.lnbits;
  lnd = config.services.lnd;
  types = lib.types;

  # True when any backend in services.lnbits.backends has enable = true.
  # Each backend is an attrset with at least `enable`; `lib.any` short-circuits.
  anyBackendEnabled = lib.any (b: b.enable) (lib.attrValues cfg.backends);
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

    logFile = lib.mkOption {
      type = types.str;
      default = "${cfg.dataDir}/lnbits.log";
      defaultText = lib.literalExpression ''"''${cfg.dataDir}/lnbits.log"'';
      description = ''
        Path to the file that receives a tee'd copy of the LNbits process
        output. Useful for inspecting which funding source was picked up at
        startup, since devenv's native process manager does not split
        per-process logs.
      '';
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

    # Funding source backends. At most one may be enabled; enabling one
    # selects the corresponding LNBITS_BACKEND_WALLET_CLASS and emits the
    # backend-specific env vars. New backends (corelightning, phoenixd, …)
    # plug in as sibling attrsets following the same shape.
    backends.lnd = {
      enable = lib.mkEnableOption "LND gRPC as the LNbits funding source (LndWallet)";

      endpoint = lib.mkOption {
        type = types.str;
        default = lnd.rpcAddress;
        defaultText = lib.literalExpression "config.services.lnd.rpcAddress";
        description = "LND gRPC host (maps to LND_GRPC_ENDPOINT).";
      };

      port = lib.mkOption {
        type = types.port;
        default = lnd.rpcPort;
        defaultText = lib.literalExpression "config.services.lnd.rpcPort";
        description = "LND gRPC port (maps to LND_GRPC_PORT).";
      };

      certFile = lib.mkOption {
        type = types.str;
        default = lnd.certFile;
        defaultText = lib.literalExpression "config.services.lnd.certFile";
        description = "Path to the LND TLS certificate (maps to LND_GRPC_CERT).";
      };

      macaroonFile = lib.mkOption {
        type = types.str;
        default = lnd.macaroonFile;
        defaultText = lib.literalExpression "config.services.lnd.macaroonFile";
        description = ''
          Path to the LND admin macaroon (maps to LND_GRPC_MACAROON). May also
          be set to a hex-encoded macaroon string — lnbits accepts both.
        '';
      };
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = lib.length (lib.filter (b: b.enable) (lib.attrValues cfg.backends)) <= 1;
        message = "services.lnbits: at most one backend under services.lnbits.backends may have enable = true.";
      }
    ];

    # Auto-enable services.lnd when the lnd backend is active so the module
    # composes cleanly with the rest of the stack. User-overridable via
    # `services.lnd.enable = lib.mkForce false;` if an external LND is used.
    services.lnd.enable = lib.mkIf cfg.backends.lnd.enable (lib.mkDefault true);

    packages = [ cfg.package ];

    env = lib.mkMerge [
      {
        LNBITS_DATA_FOLDER = "${cfg.dataDir}/data";
        LNBITS_EXTENSIONS_PATH = cfg.dataDir;
        LNBITS_BACKEND_WALLET_CLASS =
          if cfg.backends.lnd.enable then "LndWallet"
          else if anyBackendEnabled then
            throw "services.lnbits: unhandled backend selection (this is a module bug)"
          else "VoidWallet";
      }
      (lib.mkIf cfg.backends.lnd.enable {
        LND_GRPC_ENDPOINT = cfg.backends.lnd.endpoint;
        LND_GRPC_PORT = toString cfg.backends.lnd.port;
        LND_GRPC_CERT = cfg.backends.lnd.certFile;
        LND_GRPC_MACAROON = cfg.backends.lnd.macaroonFile;
      })
      cfg.env
    ];

    processes.lnbits = {
      # lnbits/app.py mounts StaticFiles with the relative path
      # Path("lnbits", "static"), so the server's cwd must contain the
      # `lnbits/` package or startup fails at import.
      cwd = "${cfg.package}/lib/python3.12/site-packages";
      # When an LND-backed funding source is selected, the lnd process must
      # be healthy before lnbits attempts to open the gRPC connection.
      after = lib.optional cfg.backends.lnd.enable "devenv:processes:lnd";
      exec = lib.getExe (
        pkgs.writeShellApplication {
          name = "lnbits-start";
          runtimeInputs = [ cfg.package pkgs.coreutils ];
          text = ''
            mkdir -p "${cfg.dataDir}/data" "$(dirname "${cfg.logFile}")"
            # Tee the LNbits process output so test harnesses (and operators)
            # can assert on startup banners without scraping the aggregated
            # devenv-tasks log.
            lnbits --host "${cfg.host}" --port "${toString cfg.port}" 2>&1 \
              | tee -a "${cfg.logFile}"
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
        depends_on = lib.mkIf cfg.backends.lnd.enable {
          lnd.condition = "process_healthy";
        };
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
