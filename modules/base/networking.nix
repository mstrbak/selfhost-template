{ lib, userConfig, ... }:
{
  networking = {
    hostName = userConfig.hostname;
    useDHCP = lib.mkDefault true;

    firewall = {
      enable = true;
      # Public 22/tcp open only while fallback is on. Flip off in config.nix
      # once Tailscale is confirmed working.
      allowedTCPPorts = lib.optionals userConfig.publicSshFallback [ 22 ];
      # tailscale0 is fully trusted — Tailscale enforces ACLs.
      trustedInterfaces = [ "tailscale0" ];
      # Don't break Tailscale NAT traversal.
      checkReversePath = "loose";
    };
  };
}
