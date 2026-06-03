{ pkgs, userConfig, ports, ... }:
{
  systemd.tmpfiles.rules = [
    "d /mnt/appdata/searxng         0755 root root - -"
    "d /mnt/appdata/searxng/config  0755 root root - -"
  ];

  systemd.services.docker-searxng = {
    after    = [ "create-traefik-network.service" ];
    requires = [ "create-traefik-network.service" ];
  };

  virtualisation.oci-containers.containers.searxng = {
    image = "docker.io/searxng/searxng:latest";
    autoStart = true;
    extraOptions = [
      "--network=traefik"
      "--label=traefik.enable=true"
      "--label=traefik.http.routers.searxng.rule=Host(`search.${userConfig.domain}`)"
      "--label=traefik.http.routers.searxng.entrypoints=websecure"
      "--label=traefik.http.routers.searxng.tls=true"
      "--label=traefik.http.routers.searxng.tls.certresolver=letsencrypt"
      "--label=traefik.http.services.searxng.loadbalancer.server.port=8080"
    ];
    environment = {
      SEARXNG_BASE_URL = "https://search.${userConfig.domain}/";
    };
    volumes = [
      "/mnt/appdata/searxng/config:/etc/searxng"
    ];
  };
}
