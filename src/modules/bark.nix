{ pkgs
, lib
, config
, inputs ? { }
, ...
}:
let
  cfg = config.services.bark;
  bitcoind = config.services.bitcoind;
  postgres = config.services.postgres;
  types = lib.types;
  system = pkgs.stdenv.hostPlatform.system;

  # Modeled on devenv's src/modules/lib.nix `_mkInputError`/`getInput`, but
  # thrown locally: the consumer's pinned devenv may not ship `getInput`.
  # Kept behind lazy option defaults so the throw only fires when a package
  # default is actually needed (i.e. the component is enabled and the user
  # did not set `package` explicitly).
  barkInput = inputs.bark or (throw ''
    To use 'services.bark', add the bark flake to your devenv.yaml:

      inputs:
        bark:
          url: gitlab:ark-bitcoin/bark/bark-0.7.1
          flake: true

    Then re-run `devenv shell` so the input is fetched and locked.
  '');

  # Upstream ships prebuilt bark-server binaries for x86_64-linux only; on
  # any other host (aarch64-darwin included) build captaind from the pinned
  # source tree instead.
  upstreamServer = barkInput.packages.${system} or { };
  defaultServerPackage = upstreamServer.bark-server or (
    pkgs.callPackage ../../nix/bark-server.nix {
      src = barkInput;
      gitHash = barkInput.rev or "unknown";
    }
  );

  network = if bitcoind.regtest then "regtest" else "bitcoin";

  captaindExe = lib.getExe' cfg.server.package "captaind";

  # Field values follow upstream's server/captaind.default.toml (the config
  # upstream ships and validates in CI), with connection details wired to the
  # sats-dev bitcoind/postgres modules.
  configFile = pkgs.writeText "captaind.toml" ''
    data_dir = "${cfg.server.dataDir}"
    network = "${network}"

    vtxo_lifetime = 4320
    min_board_amount = "20000 sat"
    vtxo_exit_delta = 144
    max_vtxo_exit_depth = 100
    max_arkoor_fanout = 4
    required_board_confirmations = 3
    min_trusted_confs = 2
    rpc_rich_errors = true
    sync_manager_block_poll_interval = "100ms"
    nursery_confirm_target_blocks = 6
    otel_deployment_name = "sats-dev"
    max_read_mailbox_items = 100

    # Mandatory on mainnet; safe on regtest, and keeps the option surface
    # identical across networks.
    require_board_funding_tx = true

    round_interval = "10s"
    round_submit_time = "2s"
    round_sign_time = "2s"
    nb_round_nonces = 8
    round_forfeit_nonces_timeout = "30s"

    offboard_session_timeout = "30s"
    offboard_check_interval = "1s"
    offboard_acceptable_fee_rate_duration = "15m"

    cln_reconnect_interval = "10s"
    invoice_check_interval = "3s"
    cln_xpay_timeout = "60s"
    invoice_check_base_delay = "10s"
    max_invoice_check_delay = "10m"
    invoice_poll_interval = "30s"
    htlc_settlement_poll_interval = "60s"
    track_all_base_delay = "1s"
    max_track_all_delay = "60s"
    htlc_expiry_delta = 40
    htlc_send_expiry_delta = 258
    max_user_invoice_cltv_delta = 250
    invoice_expiry = "48h"
    receive_htlc_forward_timeout = "3min"
    ln_receive_anti_dos_required = false
    ln_max_fee_ppm = 900000

    [fees.board]
    min_fee_sat = 330
    base_fee_sat = 100
    ppm = 1000

    [fees.offboard]
    base_fee_sat = 200
    fixed_additional_vb = 221
    ppm_expiry_table = [
      { expiry_blocks_threshold = 0, ppm = 0 },
      { expiry_blocks_threshold = 97, ppm = 1000 },
      { expiry_blocks_threshold = 199, ppm = 4000 },
      { expiry_blocks_threshold = 2161, ppm = 8000 },
    ]

    [fees.refresh]
    base_fee_sat = 150
    ppm_expiry_table = [
      { expiry_blocks_threshold = 0, ppm = 0 },
      { expiry_blocks_threshold = 97, ppm = 1000 },
      { expiry_blocks_threshold = 199, ppm = 4000 },
      { expiry_blocks_threshold = 2161, ppm = 8000 },
    ]

    [fees.lightning_receive]
    base_fee_sat = 100
    ppm = 2000

    [fees.lightning_send]
    min_fee_sat = 10
    base_fee_sat = 75
    ppm_expiry_table = [
      { expiry_blocks_threshold = 0, ppm = 0 },
      { expiry_blocks_threshold = 97, ppm = 1000 },
      { expiry_blocks_threshold = 199, ppm = 4000 },
      { expiry_blocks_threshold = 2161, ppm = 8000 },
    ]

    [vtxopool]
    vtxo_targets = [ "1000sat:10", "10000sat:10" ]
    vtxo_target_issue_threshold = 80
    vtxo_lifetime = 432
    vtxo_pre_expiry = 144
    max_vtxo_exit_depth = 3

    [fee_estimator]
    update_interval = "1m"
    history_duration = "60m"
    fallback_fee_rate_fast = "25sat/vb"
    fallback_fee_rate_regular = "10sat/vb"
    fallback_fee_rate_slow = "4sat/vb"

    [rpc]
    public_address = "${cfg.server.address}:${toString cfg.server.publicPort}"
    admin_address = "${cfg.server.address}:${toString cfg.server.adminPort}"
    integration_address = "${cfg.server.address}:${toString cfg.server.integrationPort}"

    [postgres]
    host = "127.0.0.1"
    port = ${toString postgres.port}
    name = "${cfg.server.postgres.dbName}"
    user = "${cfg.server.postgres.user}"
    password = "${cfg.server.postgres.password}"
    max_connections = 10

    [bitcoind]
    url = "http://${bitcoind.rpcAddress}:${toString bitcoind.rpcPort}"
    rpc_user = "${bitcoind.rpcUser}"
    rpc_pass = "${bitcoind.rpcPassword}"
  '';
in
{
  options.services.bark = {
    enable = lib.mkEnableOption "the bark Ark wallet CLI (bark + barkd binaries)";

    package = lib.mkOption {
      type = types.package;
      default = barkInput.packages.${system}.bark;
      defaultText = lib.literalExpression "inputs.bark.packages.\${system}.bark";
      description = ''
        The bark package to use, providing the `bark` CLI and `barkd` daemon
        binaries. Typically sourced from the external flake input
        `gitlab:ark-bitcoin/bark`.
      '';
    };

    server = {
      enable = lib.mkEnableOption "captaind, the Ark server (ASP)";

      package = lib.mkOption {
        type = types.package;
        default = defaultServerPackage;
        defaultText = lib.literalExpression "inputs.bark.packages.\${system}.bark-server or (source build via nix/bark-server.nix)";
        description = ''
          The bark-server package to use, providing `captaind` and
          `watchmand`. Defaults to upstream's prebuilt package where shipped
          (x86_64-linux) and to a source build of the pinned bark input
          elsewhere (e.g. aarch64-darwin).
        '';
      };

      dataDir = lib.mkOption {
        type = types.str;
        default = "${config.devenv.state}/captaind";
        description = "Data directory for captaind (wallet, mnemonics, state).";
      };

      address = lib.mkOption {
        type = types.str;
        default = "127.0.0.1";
        description = "Address captaind's gRPC interfaces bind to. Keep on loopback: the admin RPC is unauthenticated.";
      };

      publicPort = lib.mkOption {
        type = types.port;
        default = 3535;
        description = "Port for the public Ark gRPC API (what bark clients connect to).";
      };

      adminPort = lib.mkOption {
        type = types.port;
        default = 3536;
        description = "Port for the unauthenticated admin gRPC API (captaind rpc).";
      };

      integrationPort = lib.mkOption {
        type = types.port;
        default = 3537;
        description = "Port for the integration manager gRPC API.";
      };

      postgres = {
        dbName = lib.mkOption {
          type = types.str;
          default = "bark-server-db";
          description = "PostgreSQL database created for and used by captaind.";
        };

        user = lib.mkOption {
          type = types.str;
          default = "bark";
          description = "PostgreSQL role created for and used by captaind.";
        };

        password = lib.mkOption {
          type = types.str;
          default = "bark";
          description = "Password for the captaind PostgreSQL role. Development-grade only; this is a throwaway regtest stack.";
        };
      };
    };

    barkd = {
      enable = lib.mkEnableOption "barkd, the bark wallet REST daemon";

      dataDir = lib.mkOption {
        type = types.str;
        default = "${config.devenv.state}/barkd";
        description = "Data directory for the barkd wallet.";
      };

      host = lib.mkOption {
        type = types.str;
        default = "127.0.0.1";
        description = "Address barkd binds to. barkd refuses a non-loopback bind unless auth is on or overridden upstream.";
      };

      port = lib.mkOption {
        type = types.port;
        default = 3000;
        description = "Port for the barkd REST API.";
      };

      noAuth = lib.mkOption {
        type = types.bool;
        default = false;
        description = ''
          Disable barkd's bearer-token authentication (--no-auth). With the
          default loopback bind this is reasonably safe; the token is
          otherwise available via `barkd --datadir <dataDir> secret show`.
        '';
      };
    };
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.enable {
      packages = [ cfg.package ];
    })

    (lib.mkIf cfg.server.enable {
      # captaind needs bitcoind with txindex and a PostgreSQL database.
      services.bitcoind = {
        enable = lib.mkDefault true;
        # types.lines concatenates, so this appends without clobbering
        # user-provided extraConfig.
        extraConfig = "txindex=1";
      };
      services.postgres = {
        enable = lib.mkDefault true;
        # captaind connects over TCP; devenv's postgres default is unix-socket
        # only (""), so opt loopback TCP in. mkDefault: user-overridable.
        listen_addresses = lib.mkDefault "127.0.0.1";
        initialDatabases = [
          {
            name = cfg.server.postgres.dbName;
            user = cfg.server.postgres.user;
            pass = cfg.server.postgres.password;
          }
        ];
      };

      # The server package is pulled in too so `captaind rpc ...` and
      # `captaind check-config` work from the shell.
      packages = [ cfg.server.package ];

      env.BARK_ASP_URL = "http://${cfg.server.address}:${toString cfg.server.publicPort}";
      env.BARK_ADMIN_RPC_ADDR = "${cfg.server.address}:${toString cfg.server.adminPort}";

      processes.captaind = {
        after = [ "devenv:processes:bitcoind" "devenv:processes:postgres" ];
        exec = lib.getExe (
          pkgs.writeShellApplication {
            name = "captaind-start";
            runtimeInputs = [ cfg.server.package ];
            text = ''
              mkdir -p "${cfg.server.dataDir}"
              # First run only: `create` initializes the server wallet
              # (writes <dataDir>/mnemonic) and creates/migrates the
              # database. `start` self-migrates the schema on every boot
              # via refinery, so no migration step is needed here.
              if [ ! -f "${cfg.server.dataDir}/mnemonic" ]; then
                echo "captaind: first run, initializing server state" >&2
                captaind -C "${configFile}" create
              fi
              exec captaind -C "${configFile}" start
            '';
          }
        );
        ready = {
          exec = ''
            ${captaindExe} rpc --addr "${cfg.server.address}:${toString cfg.server.adminPort}" wallet > /dev/null 2>&1
          '';
          period = 2;
          failure_threshold = 60;
        };
        shutdown = {
          grace = 30;
        };
      };
    })

    (lib.mkIf cfg.barkd.enable {
      packages = [ cfg.package ];

      env.BARKD_URL = "http://${cfg.barkd.host}:${toString cfg.barkd.port}";

      processes.barkd = {
        exec = lib.getExe (
          pkgs.writeShellApplication {
            name = "barkd-start";
            runtimeInputs = [ cfg.package ];
            text = ''
              mkdir -p "${cfg.barkd.dataDir}"
              exec barkd --datadir "${cfg.barkd.dataDir}" \
                --host "${cfg.barkd.host}" \
                --port ${toString cfg.barkd.port} \
                ${lib.optionalString cfg.barkd.noAuth "--no-auth"}
            '';
          }
        );
        # /ping is registered outside the authenticated /api/v1 router.
        ready = {
          exec = ''
            ${lib.getExe pkgs.curl} -sf "http://${cfg.barkd.host}:${toString cfg.barkd.port}/ping" > /dev/null 2>&1
          '';
          period = 2;
          failure_threshold = 30;
        };
      };
    })
  ];
}
