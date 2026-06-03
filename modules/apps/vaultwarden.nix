{ pkgs, userConfig, ports, ... }:
{
  systemd.tmpfiles.rules = [
    "d /var/lib/vaultwarden        0700 root root - -"
    "d /var/lib/vaultwarden/data   0700 root root - -"
    # Placeholder env file; fill via secret management. Must contain at minimum:
    #   ADMIN_TOKEN=<argon2 hash>
    "f /var/lib/vaultwarden/env    0400 root root - -"
  ];

  # Joins the `traefik` Docker network — wait for create-traefik-network.
  systemd.services.docker-vaultwarden = {
    after    = [ "create-traefik-network.service" ];
    requires = [ "create-traefik-network.service" ];
  };

  virtualisation.oci-containers.containers.vaultwarden = {
    image = "vaultwarden/server:latest";
    autoStart = true;
    extraOptions = [
      "--network=traefik"
      "--label=traefik.enable=true"
      "--label=traefik.http.routers.vaultwarden.rule=Host(`pwdman.${userConfig.domain}`)"
      "--label=traefik.http.routers.vaultwarden.entrypoints=websecure"
      "--label=traefik.http.routers.vaultwarden.tls=true"
      "--label=traefik.http.routers.vaultwarden.tls.certresolver=letsencrypt"
      "--label=traefik.http.services.vaultwarden.loadbalancer.server.port=${toString ports.vaultwarden}"
    ];
    environment = {
      DOMAIN = "https://pwdman.${userConfig.domain}";
      ROCKET_PORT = toString ports.vaultwarden;
      SIGNUPS_ALLOWED = "false";
    };
    environmentFiles = [ "/var/lib/vaultwarden/env" ];
    volumes = [
      "/var/lib/vaultwarden/data:/data"
    ];
  };
}
