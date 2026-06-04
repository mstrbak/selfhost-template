{ pkgs, userConfig, ports, ... }:
let
  appImage   = "nextcloud:30-apache";
  dbImage    = "mariadb:11";
  redisImage = "redis:7-alpine";

  dbHost    = "nextcloud-db";
  redisHost = "nextcloud-redis";
in
{
  systemd.tmpfiles.rules = [
    "d /mnt/appdata/nextcloud         0755 root root - -"
    "d /mnt/appdata/nextcloud/app     0755 root root - -"
    "d /mnt/appdata/nextcloud/db      0755 root root - -"
    "d /mnt/appdata/nextcloud/redis   0755 root root - -"
    # User file storage on shared /mnt/storage (separate from Immich's photos/).
    "d /mnt/storage/nextcloud         0755 33 33 - -"   # www-data:www-data inside container
    # Env file written by deploy workflow (SERVICES_PASSWORD → all 3 passwords).
    "f /mnt/appdata/nextcloud/env     0644 root root - -"
  ];

  systemd.services.docker-nextcloud-db = {
    after    = [ "create-traefik-network.service" ];
    requires = [ "create-traefik-network.service" ];
  };
  systemd.services.docker-nextcloud-redis = {
    after    = [ "create-traefik-network.service" ];
    requires = [ "create-traefik-network.service" ];
  };
  systemd.services.docker-nextcloud = {
    after    = [
      "create-traefik-network.service"
      "docker-nextcloud-db.service"
      "docker-nextcloud-redis.service"
    ];
    requires = [
      "create-traefik-network.service"
      "docker-nextcloud-db.service"
      "docker-nextcloud-redis.service"
    ];
  };

  virtualisation.oci-containers.containers = {
    nextcloud-db = {
      image = dbImage;
      autoStart = true;
      extraOptions = [ "--network=traefik" ];
      cmd = [ "--transaction-isolation=READ-COMMITTED" "--log-bin=binlog" "--binlog-format=ROW" ];
      environment = {
        MYSQL_DATABASE = "nextcloud";
        MYSQL_USER     = "nextcloud";
      };
      environmentFiles = [ "/mnt/appdata/nextcloud/env" ];
      volumes = [
        "/mnt/appdata/nextcloud/db:/var/lib/mysql"
      ];
    };

    nextcloud-redis = {
      image = redisImage;
      autoStart = true;
      extraOptions = [ "--network=traefik" ];
      volumes = [
        "/mnt/appdata/nextcloud/redis:/data"
      ];
    };

    nextcloud = {
      image = appImage;
      autoStart = true;
      extraOptions = [
        "--network=traefik"
        "--label=traefik.enable=true"
        "--label=traefik.http.routers.nextcloud.rule=Host(`cloud.${userConfig.domain}`)"
        "--label=traefik.http.routers.nextcloud.entrypoints=websecure"
        "--label=traefik.http.routers.nextcloud.tls=true"
        "--label=traefik.http.routers.nextcloud.tls.certresolver=letsencrypt"
        "--label=traefik.http.services.nextcloud.loadbalancer.server.port=80"
        # CalDAV/CardDAV redirects required by Nextcloud
        "--label=traefik.http.middlewares.nc-dav.redirectregex.permanent=true"
        "--label=traefik.http.middlewares.nc-dav.redirectregex.regex=https?://([^/]+)/.well-known/(card|cal)dav"
        "--label=traefik.http.middlewares.nc-dav.redirectregex.replacement=https://$${1}/remote.php/dav/"
        "--label=traefik.http.routers.nextcloud.middlewares=nc-dav@docker"
      ];
      environment = {
        MYSQL_HOST                 = dbHost;
        MYSQL_DATABASE             = "nextcloud";
        MYSQL_USER                 = "nextcloud";
        REDIS_HOST                 = redisHost;
        NEXTCLOUD_ADMIN_USER       = "admin";
        NEXTCLOUD_TRUSTED_DOMAINS  = "cloud.${userConfig.domain}";
        OVERWRITEHOST              = "cloud.${userConfig.domain}";
        OVERWRITEPROTOCOL          = "https";
        OVERWRITECLIURL            = "https://cloud.${userConfig.domain}";
        # Trust Traefik's docker network so X-Forwarded-* are honored.
        TRUSTED_PROXIES            = "172.18.0.0/16";
      };
      environmentFiles = [ "/mnt/appdata/nextcloud/env" ];
      volumes = [
        "/mnt/appdata/nextcloud/app:/var/www/html"
        "/mnt/storage/nextcloud:/var/www/html/data"
      ];
    };
  };
}
