{ pkgs, ... }:
{
  packages = [ pkgs.jq ];

  services.bitcoind = {
    enable = true;
    regtest = true;
  };

  services.lnd = {
    enable = true;
  };
}
