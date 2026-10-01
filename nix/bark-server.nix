# Builds captaind + watchmand (the `bark-server` crate) from a pinned bark
# source tree for hosts upstream's flake does not ship binaries for
# (anything but x86_64-linux — notably aarch64-darwin).
#
# Mirrors the commonSettings of upstream's nix/package-server.nix, minus the
# zig/cargo-zigbuild cross machinery that only exists for the linux release
# artifacts: here we build natively for the host with the nixpkgs toolchain.
# Structured as a candidate for an upstream PR adding darwin targets to
# `packages.bark-server`.
{ lib
, rustPlatform
, pkg-config
, protobuf
, llvmPackages
, src
, gitHash ? "unknown"
}:
let
  crateInfo = (lib.importTOML "${src}/server/Cargo.toml").package;
in
rustPlatform.buildRustPackage {
  pname = "bark-server";
  inherit (crateInfo) version;
  inherit src;

  cargoLock.lockFile = "${src}/Cargo.lock";

  # Only the server crate's binaries (captaind, watchmand), not the whole
  # workspace (wasm-testing et al. are not in its dependency graph).
  cargoBuildFlags = [ "-p" "bark-server" "--bins" ];
  doCheck = false;

  strictDeps = true;
  dontStrip = true;

  nativeBuildInputs = [
    pkg-config
    protobuf # server-rpc/cln-rpc build.rs runs protoc on the bundled protos
    llvmPackages.clang-unwrapped
  ];

  env = {
    # server/build.rs falls back to `git rev-parse`/`git tag` when these are
    # unset, which panics in the sandbox (no .git). Pin them like upstream's
    # nix/package-server.nix does.
    GIT_HASH = gitHash;
    SERVER_VERSION = "${crateInfo.version}-dev";
    LIBCLANG_PATH = "${llvmPackages.clang-unwrapped.lib}/lib/";
  };

  meta = {
    description = "Ark server (captaind + watchmand) from the bark workspace";
    homepage = "https://gitlab.com/ark-bitcoin/bark";
    license = lib.licenses.mit;
    mainProgram = "captaind";
    platforms = lib.platforms.darwin ++ lib.platforms.linux;
  };
}
