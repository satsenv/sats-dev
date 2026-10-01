{ ... }:
{
  # Enables services.bark without providing the bark flake input.
  # Evaluation must fail with instructions, not a raw attribute error.
  services.bark.enable = true;
}
