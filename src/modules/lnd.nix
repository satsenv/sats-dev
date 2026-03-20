{ pkgs
, lib
, config
, ...
}:
let
  cfg = config.services.lnd;
  bitcoind = config.services.bitcoind;
  types = lib.types;

  network = if bitcoind.regtest then "regtest" else "mainnet";

  macaroonPath = "${cfg.dataDir}/chain/bitcoin/${network}/admin.macaroon";

  lncliCmd = ''
    ${lib.getExe' cfg.package "lncli"} \
      --network ${network} \
      --rpcserver=${cfg.rpcAddress}:${toString cfg.rpcPort} \
      --lnddir="${cfg.dataDir}" \
      --tlscertpath="${cfg.dataDir}/tls.cert" \
      --macaroonpath="${macaroonPath}"'';


  configFile = pkgs.writeText "lnd.conf" (''
    datadir=${cfg.dataDir}
    tlscertpath=${cfg.dataDir}/tls.cert
    tlskeypath=${cfg.dataDir}/tls.key
    noseedbackup=1

    listen=${cfg.listenAddress}:${toString cfg.listenPort}
    rpclisten=${cfg.rpcAddress}:${toString cfg.rpcPort}
    restlisten=${cfg.restAddress}:${toString cfg.restPort}

    debuglevel=info

    bitcoin.active=1
    bitcoin.node=bitcoind
  '' + lib.optionalString bitcoind.regtest ''
    bitcoin.regtest=1
  '' + ''

    bitcoind.rpchost=${bitcoind.rpcAddress}:${toString bitcoind.rpcPort}
    bitcoind.rpcuser=${bitcoind.rpcUser}
    bitcoind.rpcpass=${bitcoind.rpcPassword}
    bitcoind.zmqpubrawblock=${bitcoind.zmq.pubrawblock}
    bitcoind.zmqpubrawtx=${bitcoind.zmq.pubrawtx}
  '' + cfg.extraConfig);
in
{
  options.services.lnd = {
    enable = lib.mkEnableOption "Lightning Network daemon";

    package = lib.mkOption {
      type = types.package;
      default = pkgs.lnd;
      description = "The lnd package to use.";
    };

    dataDir = lib.mkOption {
      type = types.str;
      default = "${config.devenv.state}/lnd";
      description = "Data directory for lnd.";
    };

    listenAddress = lib.mkOption {
      type = types.str;
      default = "127.0.0.1";
      description = "Address to listen for peer connections.";
    };

    listenPort = lib.mkOption {
      type = types.port;
      default = 9735;
      description = "Port to listen for peer connections.";
    };

    rpcAddress = lib.mkOption {
      type = types.str;
      default = "127.0.0.1";
      description = "Address to listen for gRPC connections.";
    };

    rpcPort = lib.mkOption {
      type = types.port;
      default = 10009;
      description = "Port to listen for gRPC connections.";
    };

    restAddress = lib.mkOption {
      type = types.str;
      default = "127.0.0.1";
      description = "Address to listen for REST connections.";
    };

    restPort = lib.mkOption {
      type = types.port;
      default = 8080;
      description = "Port to listen for REST connections.";
    };

    extraConfig = lib.mkOption {
      type = types.lines;
      default = "";
      description = "Extra lines appended to lnd.conf.";
    };
  };

  config = lib.mkIf cfg.enable {
    services.bitcoind = {
      enable = true;
      zmq.enable = lib.mkDefault true;
    };

    packages = [
      cfg.package
    ];

    env.LND_CERT_FILE = "${cfg.dataDir}/tls.cert";
    env.LND_MACAROON_FILE = macaroonPath;
    env.LND_GRPC_HOST = "https://${cfg.rpcAddress}:${toString cfg.rpcPort}";

    processes.lnd = {
      after = [ "devenv:processes:bitcoind" ];
      exec = lib.getExe (
        pkgs.writeShellApplication {
          name = "lnd-start";
          runtimeInputs = [ cfg.package ];
          text = ''
            mkdir -p "${cfg.dataDir}"
            exec lnd --configfile="${configFile}"
          '';
        }
      );
      ready = {
        exec = ''
          test -f "${macaroonPath}" && ${lncliCmd} getinfo > /dev/null 2>&1
        '';
        period = 2;
        failure_threshold = 30;
      };
      process-compose = {
        readiness_probe = {
          exec = {
            command = pkgs.writeShellScript "is-lnd-ready" ''
              test -f "${macaroonPath}" && ${lncliCmd} getinfo > /dev/null 2>&1
            '';
          };
          failure_threshold = 30;
          period_seconds = 2;
        };
        depends_on.bitcoind.condition = "process_healthy";
        shutdown = {
          command = ''
            ${lncliCmd} stop
          '';
          timeout_seconds = 30;
        };
      };
    };
  };
}
