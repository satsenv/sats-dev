{ pkgs, ... }:
{
  languages.nix.enable = true;

  packages = [
    pkgs.uv
  ];

  # devenv-run-tests (CLI 2.4.0) resolves its test environment from the host
  # repo's flake.lock, which a devenv.yaml project like this one doesn't have.
  # Provide the environment explicitly instead (DEVENV_TEST_ENV takes
  # precedence over the flake.lock lookup). Vendored from the devenv repo's
  # devenv-run-tests/test-env.nix at the installed CLI's rev.
  env.DEVENV_TEST_ENV = pkgs.callPackage ./nix/test-env.nix { };
}
