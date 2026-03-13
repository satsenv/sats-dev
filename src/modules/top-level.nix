{ inputs, ... }:
{
  imports = [
    "${inputs.upstream-devenv}/top-level.nix"
    ./bitcoind.nix
    ./lnd.nix
    ./podman.nix
  ];

  config = {
  };
}
