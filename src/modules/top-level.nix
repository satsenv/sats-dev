{ inputs, ... }:
{
  imports = [
    "${inputs.upstream-devenv}/top-level.nix"
    ./bitcoind.nix
    ./podman.nix
  ];

  config = {
  };
}
