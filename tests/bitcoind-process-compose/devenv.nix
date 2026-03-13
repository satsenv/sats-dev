{ pkgs, ... }:
{
  packages = [ pkgs.jq ];

  process.manager.implementation = "process-compose";

  services.bitcoind = {
    enable = true;
    regtest = true;
  };
}
