{ pkgs, userConfig, ports, ... }:
let
  # 9.4.0 has a missing Analytics.js asset that breaks the editor service worker
  # (404 cascades into "promise rejected" → UI never finishes loading).
  # Pin to a known-stable older release until upstream fixes it.
  image = "onlyoffice/documentserver:8.3.3";
in
{
  systemd.tmpfiles.rules = [
    "d /mnt/appdata/onlyoffice          0755 root root - -"
    "d /mnt/appdata/onlyoffice/data     0755 root root - -"
    "d /mnt/appdata/onlyoffice/log      0755 root root - -"
    "d /mnt/appdata/onlyoffice/cache    0755 root root - -"
    "d /mnt/appdata/onlyoffice/db       0755 root root - -"
    # Env file written by deploy workflow (SERVICES_PASSWORD → JWT_SECRET).
    "f /mnt/appdata/onlyoffice/env      0644 root root - -"
  ];

  systemd.services.docker-onlyoffice = {
    after    = [ "create-traefik-network.service" ];
    requires = [ "create-traefik-network.service" ];
  };

  virtualisation.oci-containers.containers.onlyoffice = {
    inherit image;
    autoStart = true;
    extraOptions = [
      "--network=traefik"
      # Run as root for bind-mount perms (homelab pragma).
      "--user=0:0"
      "--label=traefik.enable=true"
      "--label=traefik.http.routers.onlyoffice.rule=Host(`office.${userConfig.domain}`)"
      "--label=traefik.http.routers.onlyoffice.entrypoints=websecure"
      "--label=traefik.http.routers.onlyoffice.tls=true"
      "--label=traefik.http.routers.onlyoffice.tls.certresolver=letsencrypt"
      # DocumentServer's nginx listens on plain HTTP/80 inside the container.
      "--label=traefik.http.services.onlyoffice.loadbalancer.server.port=80"
    ];
    environment = {
      JWT_ENABLED        = "true";
      JWT_HEADER         = "Authorization";
      JWT_IN_BODY        = "true";
      USE_UNAUTHORIZED_STORAGE = "false";
      # WOPI discovery endpoint (/hosting/discovery) only exists when WOPI mode
      # is explicitly enabled. Required for OpenCloud's collaboration service.
      WOPI_ENABLED       = "true";
    };
    # JWT_SECRET supplied via env file (reuses SERVICES_PASSWORD).
    environmentFiles = [ "/mnt/appdata/onlyoffice/env" ];
    volumes = [
      "/mnt/appdata/onlyoffice/data:/var/www/onlyoffice/Data"
      "/mnt/appdata/onlyoffice/log:/var/log/onlyoffice"
      "/mnt/appdata/onlyoffice/cache:/var/lib/onlyoffice"
      "/mnt/appdata/onlyoffice/db:/var/lib/postgresql"
    ];
  };
}
