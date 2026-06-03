{ lib, userConfig, ... }:
{
  networking = {
    hostName = userConfig.hostname;
    useDHCP = false;

    # Contabo VPSes use static IPv4 assignment; DHCP is not available.
    # Values come from GH secrets via config.local.nix.
    interfaces.ens18 = {
      useDHCP = false;
      ipv4.addresses = [{
        address = userConfig.vpsIp;
        prefixLength = userConfig.vpsPrefix;
      }];
    };
    defaultGateway = userConfig.vpsGateway;

    # Public resolvers — Contabo's own DNS works too but is provider-locked.
    nameservers = [ "1.1.1.1" "1.0.0.1" ];

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
