{ inputs, ... }:
{
  imports = [
    "${inputs.upstream-devenv}/top-level.nix"
    ./bitcoind.nix
    ./lnbits.nix
    ./lnd.nix
    ./nostr-rs-relay.nix
    ./podman.nix
  ];

  config = {
  };
}
