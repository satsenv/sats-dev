{ pkgs, ... }:
{
  packages = [ pkgs.jq ];

  services.nostr-rs-relay = {
    enable = true;
  };
}
