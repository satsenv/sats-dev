{ pkgs, inputs, ... }:
{
  packages = [
    pkgs.jq
    pkgs.curl
  ];

  # services.bark.server auto-enables bitcoind; only the network choice
  # is left to the user.
  services.bitcoind.regtest = true;

  services.bark = {
    enable = true;
    package = inputs.bark.packages.${pkgs.stdenv.hostPlatform.system}.bark;

    server.enable = true;
    barkd.enable = true;
  };
}
