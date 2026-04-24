# CLAUDE.md

## Shell environment

Run all commands in this repository through `devenv shell --`:

```sh
devenv shell -- uvx showboat init docs/notes/example/demo.md "Title"
```

## Project overview

Custom devenv modules for Bitcoin and related services, tested with `devenv-run-tests`.

## Module system architecture

This project extends devenv's module system from the outside.
The key mechanism is a two-input scheme:

- `devenv-run-tests` overrides the `devenv` input to point to `src/modules/`, making `top-level.nix` the module entry point.
- `top-level.nix` imports upstream devenv's `top-level.nix` via a separate `upstream-devenv` input, then layers custom modules on top.
- Every new module must be added to the `imports` list in `src/modules/top-level.nix` or it won't be available.

The `upstream-devenv` input is declared in each test's `devenv.yaml` as `github:cachix/devenv?dir=src/modules`.

## devenv-run-tests behavior

- `devenv-run-tests run tests` scans the `tests/` directory for subdirectories; each subdirectory is a test.
- Each test is copied to a temp dir, git-initialized, then `devenv test` runs inside it.
- The argument to `run` is a parent directory, not a test name. Use `--only <name>` to filter.
- `.test.sh` must be executable (`chmod +x`).

## devenv test internals

- `devenv test` provides `wait_for_processes` and `wait_for_port` as exported shell functions in the test environment.
- `wait_for_processes` blocks until all processes with readiness probes report healthy.
- The native process manager uses the `ready` option on process definitions (`lib/ready.nix` submodule type with `exec`, `http`, or `notify`).
- The `process-compose` readiness probe (under `process-compose.readiness_probe`) is only used by the process-compose backend, not the native manager.
- For compatibility with both backends, define both `ready` and `process-compose.readiness_probe`.

## Test output visibility

- Write test output to stderr (`>&2`) so it appears in `devenv-run-tests` output.

## Documenting work with showboat

Always use showboat (`uvx showboat`) to document implementation sessions.
Create or append to a demo document under `docs/notes/` that captures what was done, key commands, and test results.

Commands:

- `showboat init <file> <title>` to start a new document
- `showboat note <file> "text"` to add commentary
- `showboat exec <file> bash "command"` to run a command and capture its output
- `showboat pop <file>` to remove the last entry (use after failed exec before retrying)
- `showboat verify <file>` to re-run all code blocks and check outputs still match
- `showboat image <file> <path>` to embed an image

## Development workflow

Always follow a red-green testing approach when implementing or modifying modules:

1. Write the test first (`.test.sh` and `devenv.nix` under `tests/<name>/`) that exercises the desired behavior.
2. Run the test and confirm it fails (red) for the expected reason.
3. Implement the minimum module code in `src/modules/` to make the test pass.
4. Run the test again and confirm it passes (green).
5. Refactor if needed, re-running the test after each change to ensure it stays green.

Start every implementation task by creating or updating the test, not the module code.

## Session completion checklist

Once the red-green cycle is green, do all of the following in order before declaring the task complete or committing:

1. **Update README.md** — whenever a module is added, renamed, or its public option surface changes, revise the relevant section of `README.md` (and add a new section for new modules) so it stays in sync with `src/modules/`.
2. **Update `docs/src/index.md`** — keep the "Available modules" list and any usage examples there aligned with the same module changes that prompted the README update.
3. **Document with showboat** — append this session's commands, notes, and outputs to `docs/notes/<topic>/demo.md`. See "Documenting work with showboat" above for the commands.
4. **Review with `/tuicr`** — invoke the tuicr skill against the repo to interactively inspect staged + unstaged diffs plus the pending commits before committing.
5. **Commit with jj** — describe each logical change separately; atomic, conventional subject lines (`feat(...)`, `docs(...)`, etc).

Skipping steps 1–4 is a regression. If the user says "commit", treat that as step 5 only once the earlier steps are done; otherwise run them first (or ask if skipping is intentional).

## Test script conventions

- Use `jq` for JSON parsing (add `pkgs.jq` to `packages` in the test's `devenv.nix`).
- Call `wait_for_processes` at the start of any test that depends on running services.
