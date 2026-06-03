{ pkgs, userConfig, ports, ... }:
let
  image = "opencloudeu/opencloud-rolling:latest";
in
{
  systemd.tmpfiles.rules = [
    "d /mnt/appdata/opencloud         0750 root root - -"
    "d /mnt/appdata/opencloud/config  0750 root root - -"
    "d /mnt/appdata/opencloud/data    0750 root root - -"
    # Env file written by deploy workflow (SERVICES_PASSWORD → IDM_ADMIN_PASSWORD)
    "f /mnt/appdata/opencloud/env     0400 root root - -"
  ];

  systemd.services.docker-opencloud = {
    after    = [ "create-traefik-network.service" ];
    requires = [ "create-traefik-network.service" ];
  };

  virtualisation.oci-containers.containers.opencloud = {
    inherit image;
    autoStart = true;
    cmd = [ "server" ];
    extraOptions = [
      "--network=traefik"
      "--label=traefik.enable=true"
      "--label=traefik.http.routers.opencloud.rule=Host(`cloud.${userConfig.domain}`)"
      "--label=traefik.http.routers.opencloud.entrypoints=websecure"
      "--label=traefik.http.routers.opencloud.tls=true"
      "--label=traefik.http.routers.opencloud.tls.certresolver=letsencrypt"
      "--label=traefik.http.services.opencloud.loadbalancer.server.port=${toString ports.opencloud}"
    ];
    environment = {
      OC_URL              = "https://cloud.${userConfig.domain}";
      OC_LOG_LEVEL        = "info";
      OC_INSECURE         = "false";
      PROXY_HTTP_ADDR     = "0.0.0.0:${toString ports.opencloud}";
      # Admin identity — password comes from env file (SERVICES_PASSWORD).
      IDM_ADMIN_USERNAME  = "admin";
      IDM_CREATE_DEMO_USERS = "false";
    };
    environmentFiles = [ "/mnt/appdata/opencloud/env" ];
    volumes = [
      "/mnt/appdata/opencloud/config:/etc/opencloud"
      "/mnt/appdata/opencloud/data:/var/lib/opencloud"
      # OpenCloud reads/writes user data on shared storage (same dir Immich uses for photos).
      "/mnt/storage:/mnt/storage"
    ];
  };
}
