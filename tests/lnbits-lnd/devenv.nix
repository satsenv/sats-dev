{ pkgs, inputs, ... }:
{
  packages = [ pkgs.curl pkgs.jq ];

  services.lnbits = {
    enable = true;
    package = inputs.lnbits.packages.${pkgs.stdenv.hostPlatform.system}.default;
    backends.lnd.enable = true;
    env = {
      LNBITS_ADMIN_UI = "false";
    };
  };
}
