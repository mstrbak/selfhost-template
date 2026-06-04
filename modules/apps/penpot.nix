{ pkgs, userConfig, ports, ... }:
let
  flags = "enable-login-with-password disable-email-verification disable-smtp";
in
{
  systemd.tmpfiles.rules = [
    "d /mnt/appdata/penpot          0755 root root - -"
    "d /mnt/appdata/penpot/db       0755 root root - -"
    "d /mnt/appdata/penpot/redis    0755 root root - -"
    "d /mnt/appdata/penpot/assets   0755 root root - -"
    # Env file written by deploy workflow (SERVICES_PASSWORD → DB + secret key).
    "f /mnt/appdata/penpot/env      0644 root root - -"
  ];

  systemd.services.docker-penpot-redis = {
    after    = [ "create-traefik-network.service" ];
    requires = [ "create-traefik-network.service" ];
  };
  systemd.services.docker-penpot-postgres = {
    after    = [ "create-traefik-network.service" ];
    requires = [ "create-traefik-network.service" ];
  };
  systemd.services.docker-penpot-backend = {
    after    = [
      "create-traefik-network.service"
      "docker-penpot-postgres.service"
      "docker-penpot-redis.service"
    ];
    requires = [
      "create-traefik-network.service"
      "docker-penpot-postgres.service"
      "docker-penpot-redis.service"
    ];
  };
  systemd.services.docker-penpot-exporter = {
    after    = [ "create-traefik-network.service" "docker-penpot-redis.service" ];
    requires = [ "create-traefik-network.service" "docker-penpot-redis.service" ];
  };
  systemd.services.docker-penpot-frontend = {
    after    = [
      "create-traefik-network.service"
      "docker-penpot-backend.service"
      "docker-penpot-exporter.service"
    ];
    requires = [
      "create-traefik-network.service"
      "docker-penpot-backend.service"
      "docker-penpot-exporter.service"
    ];
  };

  virtualisation.oci-containers.containers = {
    penpot-redis = {
      image = "redis:7-alpine";
      autoStart = true;
      extraOptions = [ "--network=traefik" ];
      volumes = [ "/mnt/appdata/penpot/redis:/data" ];
    };

    penpot-postgres = {
      image = "postgres:16-alpine";
      autoStart = true;
      extraOptions = [ "--network=traefik" ];
      environment = {
        POSTGRES_USER = "penpot";
        POSTGRES_DB   = "penpot";
      };
      environmentFiles = [ "/mnt/appdata/penpot/env" ];
      volumes = [ "/mnt/appdata/penpot/db:/var/lib/postgresql/data" ];
    };

    penpot-backend = {
      image = "penpotapp/backend:latest";
      autoStart = true;
      extraOptions = [ "--network=traefik" ];
      environment = {
        PENPOT_FLAGS                       = flags;
        PENPOT_DATABASE_URI                = "postgresql://penpot-postgres/penpot";
        PENPOT_DATABASE_USERNAME           = "penpot";
        PENPOT_REDIS_URI                   = "redis://penpot-redis/0";
        PENPOT_ASSETS_STORAGE_BACKEND      = "assets-fs";
        PENPOT_STORAGE_ASSETS_FS_DIRECTORY = "/opt/data/assets";
        PENPOT_TELEMETRY_ENABLED           = "false";
        PENPOT_PUBLIC_URI                  = "https://design.${userConfig.domain}";
      };
      environmentFiles = [ "/mnt/appdata/penpot/env" ];
      volumes = [ "/mnt/appdata/penpot/assets:/opt/data/assets" ];
    };

    penpot-exporter = {
      image = "penpotapp/exporter:latest";
      autoStart = true;
      extraOptions = [ "--network=traefik" ];
      environment = {
        PENPOT_FLAGS      = flags;
        PENPOT_PUBLIC_URI = "http://penpot-frontend";
        PENPOT_REDIS_URI  = "redis://penpot-redis/0";
      };
      environmentFiles = [ "/mnt/appdata/penpot/env" ];
    };

    penpot-frontend = {
      image = "penpotapp/frontend:latest";
      autoStart = true;
      extraOptions = [
        "--network=traefik"
        "--label=traefik.enable=true"
        "--label=traefik.http.routers.penpot.rule=Host(`design.${userConfig.domain}`)"
        "--label=traefik.http.routers.penpot.entrypoints=websecure"
        "--label=traefik.http.routers.penpot.tls=true"
        "--label=traefik.http.routers.penpot.tls.certresolver=letsencrypt"
        "--label=traefik.http.services.penpot.loadbalancer.server.port=8080"
      ];
      environment = {
        PENPOT_FLAGS = flags;
      };
      volumes = [ "/mnt/appdata/penpot/assets:/opt/data/assets" ];
    };
  };
}
