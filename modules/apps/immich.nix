{ pkgs, userConfig, ports, ... }:
let
  # Pin to a known-good release tag rather than `release` so deploys are reproducible.
  serverImage   = "ghcr.io/immich-app/immich-server:v2.7.5";
  mlImage       = "ghcr.io/immich-app/immich-machine-learning:v2.7.5";
  postgresImage = "ghcr.io/immich-app/postgres:14-vectorchord0.4.3-pgvectors0.2.0";
  redisImage    = "docker.io/valkey/valkey:9";

  # Internal DNS names within the `traefik` Docker network.
  dbHost     = "immich-postgres";
  redisHost  = "immich-redis";
  mlHost     = "immich-machine-learning";

  # Immich server's UPLOAD_LOCATION is a single dir; we split subfolders via
  # bind-mounts so originals live on /mnt/storage and derivatives on /mnt/appdata.
  uploadRoot = "/usr/src/app/upload";
in
{
  systemd.tmpfiles.rules = [
    # Container state on root disk (small, fast)
    "d /mnt/appdata                          0755 root root - -"
    "d /mnt/appdata/immich                   0755 root root - -"
    "d /mnt/appdata/immich/db                0700 root root - -"
    # Valkey image runs as UID 999 internally — needs write access for RDB snapshots.
    "d /mnt/appdata/immich/redis             0700 999 999 - -"
    "d /mnt/appdata/immich/model-cache       0755 root root - -"
    # Immich derivative folders (thumbs, transcodes, profile pics, temp uploads, backups)
    "d /mnt/appdata/immich/thumbs            0755 root root - -"
    "d /mnt/appdata/immich/encoded-video     0755 root root - -"
    "d /mnt/appdata/immich/profile           0755 root root - -"
    "d /mnt/appdata/immich/upload            0755 root root - -"
    "d /mnt/appdata/immich/backups           0755 root root - -"
    # Originals — user-visible storage, also shared with OpenCloud
    "d /mnt/storage                          0755 root root - -"
    "d /mnt/storage/photos                   0755 root root - -"
    # Env file written by deploy workflow (SERVICES_PASSWORD → DB_PASSWORD)
    "f /mnt/appdata/immich/env               0400 root root - -"
  ];

  systemd.services.docker-immich-postgres = {
    after    = [ "create-traefik-network.service" ];
    requires = [ "create-traefik-network.service" ];
  };
  systemd.services.docker-immich-redis = {
    after    = [ "create-traefik-network.service" ];
    requires = [ "create-traefik-network.service" ];
  };
  systemd.services.docker-immich-machine-learning = {
    after    = [ "create-traefik-network.service" ];
    requires = [ "create-traefik-network.service" ];
  };
  systemd.services.docker-immich-server = {
    after    = [
      "create-traefik-network.service"
      "docker-immich-postgres.service"
      "docker-immich-redis.service"
    ];
    requires = [
      "create-traefik-network.service"
      "docker-immich-postgres.service"
      "docker-immich-redis.service"
    ];
  };

  virtualisation.oci-containers.containers = {
    immich-postgres = {
      image = postgresImage;
      autoStart = true;
      extraOptions = [ "--network=traefik" ];
      environment = {
        POSTGRES_DB   = "immich";
        POSTGRES_USER = "immich";
      };
      environmentFiles = [ "/mnt/appdata/immich/env" ];
      volumes = [
        "/mnt/appdata/immich/db:/var/lib/postgresql/data"
      ];
    };

    immich-redis = {
      image = redisImage;
      autoStart = true;
      extraOptions = [ "--network=traefik" ];
      volumes = [
        "/mnt/appdata/immich/redis:/data"
      ];
    };

    immich-machine-learning = {
      image = mlImage;
      autoStart = true;
      extraOptions = [ "--network=traefik" ];
      environment = {
        # Force IPv4 bind — default `[::]:3003` was unreachable from
        # immich-server over the IPv4-only Docker bridge.
        IMMICH_HOST = "0.0.0.0";
      };
      volumes = [
        "/mnt/appdata/immich/model-cache:/cache"
      ];
    };

    immich-server = {
      image = serverImage;
      autoStart = true;
      extraOptions = [
        "--network=traefik"
        "--label=traefik.enable=true"
        "--label=traefik.http.routers.immich.rule=Host(`photos.${userConfig.domain}`)"
        "--label=traefik.http.routers.immich.entrypoints=websecure"
        "--label=traefik.http.routers.immich.tls=true"
        "--label=traefik.http.routers.immich.tls.certresolver=letsencrypt"
        "--label=traefik.http.services.immich.loadbalancer.server.port=${toString ports.immich}"
      ];
      environment = {
        DB_HOSTNAME       = dbHost;
        DB_USERNAME       = "immich";
        DB_DATABASE_NAME  = "immich";
        REDIS_HOSTNAME    = redisHost;
        IMMICH_MACHINE_LEARNING_URL = "http://${mlHost}:3003";
      };
      environmentFiles = [ "/mnt/appdata/immich/env" ];
      volumes = [
        # Originals → shared user storage
        "/mnt/storage/photos:${uploadRoot}/library"
        # Derivatives → /appdata
        "/mnt/appdata/immich/thumbs:${uploadRoot}/thumbs"
        "/mnt/appdata/immich/encoded-video:${uploadRoot}/encoded-video"
        "/mnt/appdata/immich/profile:${uploadRoot}/profile"
        "/mnt/appdata/immich/upload:${uploadRoot}/upload"
        "/mnt/appdata/immich/backups:${uploadRoot}/backups"
      ];
    };
  };
}
