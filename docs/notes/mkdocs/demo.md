# mkdocs documentation setup

*2026-03-20T16:02:04Z by Showboat 0.6.1*
<!-- showboat-id: 6253e396-808d-41f2-ac66-f8f95fae331d -->

Setting up mkdocs with Material theme to serve project documentation. The generated options markdown from docs/options.nix is included via the include-markdown plugin. A devenv process runs mkdocs serve for live reload during development.

The docs environment lives in docs/ as a separate devenv with its own devenv.yaml, devenv.nix, and pyproject.toml. Python dependencies are managed via uv sync (languages.python.uv.sync.enable). The generate-options script runs nix build -f options.nix and copies the result to docs/generated/options.md. The options.md reference page uses include-markdown to pull in the generated file. Running devenv up in docs/ starts mkdocs serve with live reload.

```bash
cat docs/devenv.nix
```

```output
{ config, lib, pkgs, ... }:
{
  languages.python = {
    enable = true;
    uv = {
      enable = true;
      sync.enable = true;
    };
    venv.enable = true;
  };

  scripts."generate-options" = {
    description = "Generate module options documentation.";
    exec = ''
      mkdir -p ${config.devenv.root}/generated
      out=$(nix build -f ${config.devenv.root}/options.nix --no-link --print-out-paths)
      install -m 644 "$out" ${config.devenv.root}/generated/options.md
      echo "Generated docs/generated/options.md"
    '';
  };

  processes.docs = {
    exec = ''
      generate-options
      mkdocs serve -f ${config.devenv.root}/mkdocs.yml
    '';
  };
}
```

```bash
cat docs/mkdocs.yml
```

```output
site_name: sats-dev
site_description: "Custom devenv modules for Bitcoin and related services"
docs_dir: "src"
strict: true
theme:
  name: material
  palette:
    - media: "(prefers-color-scheme: light)"
      scheme: default
      toggle:
        icon: material/weather-sunny
        name: Switch to dark mode
    - media: "(prefers-color-scheme: dark)"
      scheme: slate
      toggle:
        icon: material/weather-night
        name: Switch to light mode
  features:
    - content.code.copy
    - content.lazy
    - navigation.sections
    - navigation.top
    - search.share
    - toc.follow

plugins:
  search: {}
  include-markdown: {}

markdown_extensions:
  - tables
  - admonition
  - pymdownx.highlight:
      anchor_linenums: true
      use_pygments: true
  - pymdownx.superfences
  - pymdownx.tabbed:
      alternate_style: true
  - attr_list
  - toc:
      permalink: true

nav:
  - Home: index.md
  - Reference:
    - Module options: reference/options.md
```
