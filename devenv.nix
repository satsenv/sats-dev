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

  # The bark module sources packages from the `gitlab:ark-bitcoin/bark`
  # flake; its nixConfig (which points at their Cachix cache) only applies
  # when that flake is the root, so opt its consumers in here. NIX_CONFIG is
  # merged over the user/system nix.conf for nix commands run from this
  # shell (devenv-run-tests included); other settings like access-tokens
  # still come from nix.conf.
  env.NIX_CONFIG = ''
    extra-substituters = https://bark.cachix.org
    extra-trusted-public-keys = bark.cachix.org-1:Iaihe4ABbOQz1CHBoYUZS/sHVAcISasJZ+lL3I4gRB0=
  '';
}
