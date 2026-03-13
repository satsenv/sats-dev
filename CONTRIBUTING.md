# Contributing

## Development

To develop against a local checkout of this repository, use a path reference in your project's `devenv.yaml`:

```yaml
inputs:
  sats-dev:
    url: path:/path/to/sats-dev?dir=src/modules
imports:
  - sats-dev
```

## Testing

Tests use `devenv-run-tests` from the devenv repository.
Each test is a subdirectory under `tests/` containing at minimum a `devenv.nix`, a `devenv.yaml`, and an executable `.test.sh`.

Run all tests:

```sh
devenv-run-tests run tests
```

Run a specific test:

```sh
devenv-run-tests run --only bitcoind tests
```

### Writing tests

A test directory needs three files:

- `devenv.yaml` declaring the `upstream-devenv` input
- `devenv.nix` enabling the modules under test
- `.test.sh` (must be executable) containing the test logic

Write test output to stderr (`>&2`) so it appears in the test runner output.

## Project structure

```
src/modules/
  top-level.nix      # Module entry point, imports upstream devenv + custom modules
  flake.nix          # Flake exposing modules directory
  bitcoind.nix       # Bitcoin daemon with regtest support
  podman.nix         # Podman machine management
tests/
  bitcoind/          # Integration test for bitcoind (native process manager)
  bitcoind-process-compose/  # Same test with process-compose
  podman/            # Integration test for podman-machine
```
