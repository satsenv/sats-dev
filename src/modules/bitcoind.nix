{ pkgs
, lib
, config
, ...
}:
let
  cfg = config.services.bitcoind;
  types = lib.types;

  zmq = cfg.zmq;

  zmqConfig = lib.optionalString zmq.enable ''
    zmqpubrawblock=${zmq.pubrawblock}
    zmqpubrawtx=${zmq.pubrawtx}
  '';

  # Extract port from tcp://host:port URL
  zmqPorts = lib.optionals zmq.enable [
    (lib.last (lib.splitString ":" zmq.pubrawblock))
    (lib.last (lib.splitString ":" zmq.pubrawtx))
  ];

  zmqReadyCheck = lib.concatMapStringsSep "\n" (port: ''
    ${lib.getExe' pkgs.netcat-gnu "nc"} -z 127.0.0.1 ${port}
  '') zmqPorts;

  configFile = pkgs.writeText "bitcoin.conf" (''
    nodebuglogfile=1
    logtimestamps=1
    server=1
  '' + zmqConfig + lib.optionalString cfg.regtest ''
    regtest=1
    [regtest]
  '' + ''
    rpcbind=${cfg.rpcAddress}
    rpcport=${toString cfg.rpcPort}
    rpcallowip=${cfg.rpcAddress}/0
    rpcuser=${cfg.rpcUser}
    rpcpassword=${cfg.rpcPassword}
  '' + cfg.extraConfig);
in
{
  options.services.bitcoind = {
    enable = lib.mkEnableOption "Bitcoin daemon";

    package = lib.mkOption {
      type = types.package;
      default = pkgs.bitcoind;
      description = "The bitcoind package to use.";
    };

    regtest = lib.mkOption {
      type = types.bool;
      default = false;
      description = "Enable regtest mode.";
    };

    dataDir = lib.mkOption {
      type = types.str;
      default = "${config.devenv.state}/bitcoind";
      description = "Data directory for bitcoind.";
    };

    rpcAddress = lib.mkOption {
      type = types.str;
      default = "127.0.0.1";
      description = "Address for the RPC server to bind to.";
    };

    rpcPort = lib.mkOption {
      type = types.port;
      default = if cfg.regtest then 18443 else 8332;
      description = "Port for the RPC server.";
    };

    rpcUser = lib.mkOption {
      type = types.str;
      default = "devenv";
      description = "RPC username.";
    };

    rpcPassword = lib.mkOption {
      type = types.str;
      default = "devenv";
      description = "RPC password.";
    };

    zmq = {
      enable = lib.mkEnableOption "ZMQ pub/sub endpoints";

      pubrawblock = lib.mkOption {
        type = types.str;
        default = "tcp://127.0.0.1:28332";
        description = "ZMQ endpoint for publishing raw blocks.";
      };

      pubrawtx = lib.mkOption {
        type = types.str;
        default = "tcp://127.0.0.1:28333";
        description = "ZMQ endpoint for publishing raw transactions.";
      };
    };

    extraConfig = lib.mkOption {
      type = types.lines;
      default = "";
      description = "Extra lines appended to bitcoin.conf.";
    };
  };

  config = lib.mkIf cfg.enable {
    packages = [
      cfg.package
    ];

    processes.bitcoind = {
      exec = lib.getExe (
        pkgs.writeShellApplication {
          name = "bitcoind-start";
          runtimeInputs = [ cfg.package ];
          text = ''
            mkdir -p "${cfg.dataDir}"
            exec bitcoind -datadir="${cfg.dataDir}" -conf="${configFile}"
          '';
        }
      );
      ready = {
        exec = ''
          ${lib.getExe' cfg.package "bitcoin-cli"} \
            -rpcuser="${cfg.rpcUser}" \
            -rpcpassword="${cfg.rpcPassword}" \
            -rpcport=${toString cfg.rpcPort} \
            ${lib.optionalString cfg.regtest "-regtest"} \
            getblockchaininfo > /dev/null 2>&1
          ${lib.optionalString zmq.enable zmqReadyCheck}
        '';
        period = 2;
        failure_threshold = 20;
      };
      process-compose = {
        readiness_probe = {
          exec = {
            command = pkgs.writeShellScript "is-bitcoind-ready" ''
              ${lib.getExe' cfg.package "bitcoin-cli"} \
                -datadir="${cfg.dataDir}" \
                -rpcuser="${cfg.rpcUser}" \
                -rpcpassword="${cfg.rpcPassword}" \
                ${lib.optionalString cfg.regtest "-regtest"} \
                getblockchaininfo > /dev/null 2>&1
              ${lib.optionalString zmq.enable zmqReadyCheck}
            '';
          };
          failure_threshold = 20;
          period_seconds = 2;
        };
        shutdown = {
          command = ''
            ${lib.getExe' cfg.package "bitcoin-cli"} \
              -datadir="${cfg.dataDir}" \
              -rpcuser="${cfg.rpcUser}" \
              -rpcpassword="${cfg.rpcPassword}" \
              ${lib.optionalString cfg.regtest "-regtest"} \
              stop
          '';
          timeout_seconds = 30;
        };
      };
    };

    env.BITCOIN_RPC_URL = "http://${cfg.rpcUser}:${cfg.rpcPassword}@${cfg.rpcAddress}:${toString cfg.rpcPort}";
  };
}
