{ pkgs, inputs, ... }:
{
  packages = [ pkgs.curl ];

  services.lnbits = {
    enable = true;
    package = inputs.lnbits.packages.${pkgs.stdenv.hostPlatform.system}.default;
    env = {
      LNBITS_ADMIN_UI = "false";
    };
  };
}
