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
