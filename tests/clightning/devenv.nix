{ pkgs, ... }:
{
  packages = [ pkgs.jq ];

  services.bitcoind = {
    enable = true;
    regtest = true;
  };

  services.clightning = {
    enable = true;
  };
}
