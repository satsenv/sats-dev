{ ... }:

{
  # Entry point when this flake is imported via `imports: - sats-dev`
  # in a consumer's devenv.yaml. Delegates to top-level.nix which wires
  # up all sats-dev modules (bitcoind, lnd, ...).
  imports = [ ./top-level.nix ];
}
