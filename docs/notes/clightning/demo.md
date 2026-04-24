# clightning devenv module

*2026-04-24T14:52:06Z by Showboat 0.6.1*
<!-- showboat-id: 016eb41d-29ce-40a0-bda1-b1f4e271a89e -->

Red-green approach: write test first exercising a clightning devenv module that starts lightningd on regtest, connects to bitcoind, and exposes lightning-cli.

Test passes: clightning spins up on regtest, connects to bitcoind, reports pubkey and blockheight, and the CLIGHTNING_RPC_FILE env var points at a live socket. Module added at src/modules/clightning.nix and imported in top-level.nix.
