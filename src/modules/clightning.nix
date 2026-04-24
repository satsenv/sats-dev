{ pkgs
, lib
, config
, ...
}:
let
  cfg = config.services.clightning;
  bitcoind = config.services.bitcoind;
  types = lib.types;

  configFile = pkgs.writeText "lightningd-config" (''
    network=${cfg.network}
    bind-addr=${cfg.address}:${toString cfg.port}
    bitcoin-rpcconnect=${bitcoind.rpcAddress}
    bitcoin-rpcport=${toString bitcoind.rpcPort}
    bitcoin-rpcuser=${bitcoind.rpcUser}
    bitcoin-rpcpassword=${bitcoind.rpcPassword}
    wallet=${cfg.wallet}
    rpc-file-mode=0660
    log-timestamps=false
  '' + lib.optionalString (!cfg.useBcliPlugin) ''
    disable-plugin=bcli
  '' + cfg.extraConfig);

  lightningCliCmd = ''
    ${lib.getExe' cfg.package "lightning-cli"} \
      --lightning-dir="${cfg.dataDir}" \
      --network=${cfg.network}'';
in
{
  options.services.clightning = {
    enable = lib.mkEnableOption "Core Lightning (clightning) daemon";

    package = lib.mkOption {
      type = types.package;
      default = pkgs.clightning;
      description = "The clightning package to use.";
    };

    dataDir = lib.mkOption {
      type = types.str;
      default = "${config.devenv.state}/clightning";
      description = "Data directory for clightning.";
    };

    address = lib.mkOption {
      type = types.str;
      default = "127.0.0.1";
      description = "Address to listen for peer connections.";
    };

    port = lib.mkOption {
      type = types.port;
      default = 9735;
      description = "Port to listen for peer connections.";
    };

    network = lib.mkOption {
      type = types.str;
      readOnly = true;
      default = if bitcoind.regtest then "regtest" else "bitcoin";
      description = ''
        The clightning network name, derived from `services.bitcoind.regtest`.
      '';
    };

    rpcFile = lib.mkOption {
      type = types.str;
      readOnly = true;
      default = "${cfg.dataDir}/${cfg.network}/lightning-rpc";
      description = "Path to the clightning Unix-domain RPC socket.";
    };

    wallet = lib.mkOption {
      type = types.str;
      default = "sqlite3://${cfg.dataDir}/${cfg.network}/lightningd.sqlite3";
      defaultText = ''"sqlite3://''${cfg.dataDir}/''${cfg.network}/lightningd.sqlite3"'';
      example = "postgres://user:pass@localhost:5432/clightning";
      description = ''
        Wallet data scheme (sqlite3 or postgres) and location/connection
        parameters, as fully qualified data source name.
      '';
    };

    useBcliPlugin = lib.mkOption {
      type = types.bool;
      default = true;
      description = ''
        Use bitcoind (via plugin `bcli`) for getting block data.
        Disable when using plugins like `trustedcoin` that fetch block data
        from other sources.
      '';
    };

    extraConfig = lib.mkOption {
      type = types.lines;
      default = "";
      example = ''
        alias=mynode
      '';
      description = ''
        Extra lines appended to the lightningd configuration file.

        See all available options at
        https://docs.corelightning.org/reference/lightningd-config
        or by running `lightningd --help`.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    services.bitcoind = {
      enable = true;
    };

    packages = [
      cfg.package
    ];

    processes.clightning = {
      after = [ "devenv:processes:bitcoind" ];
      exec = lib.getExe (
        pkgs.writeShellApplication {
          name = "clightning-start";
          runtimeInputs = [ cfg.package ];
          text = ''
            mkdir -p "${cfg.dataDir}"
            # Remove any stale RPC socket so readiness checks can detect
            # when lightningd has accepted RPC connections.
            rm -f "${cfg.rpcFile}"
            exec lightningd \
              --lightning-dir="${cfg.dataDir}" \
              --conf="${configFile}"
          '';
        }
      );
      ready = {
        exec = ''
          test -S "${cfg.rpcFile}" && ${lightningCliCmd} getinfo > /dev/null 2>&1
        '';
        period = 2;
        failure_threshold = 30;
      };
      process-compose = {
        readiness_probe = {
          exec = {
            command = pkgs.writeShellScript "is-clightning-ready" ''
              test -S "${cfg.rpcFile}" && ${lightningCliCmd} getinfo > /dev/null 2>&1
            '';
          };
          failure_threshold = 30;
          period_seconds = 2;
        };
        depends_on.bitcoind.condition = "process_healthy";
        shutdown = {
          command = ''
            ${lightningCliCmd} stop
          '';
          timeout_seconds = 30;
        };
      };
    };
  };
}
