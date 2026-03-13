{ pkgs, ... }:
{
  languages.nix.enable = true;

  packages = [
    pkgs.uv
  ];
}
