{ pkgs, userConfig, ports, ... }:
{
  systemd.tmpfiles.rules = [
    "d /var/lib/homepage         0755 root root - -"
    "d /var/lib/homepage/config  0755 root root - -"
  ];

  # Joins the `traefik` Docker network — wait for create-traefik-network.
  systemd.services.docker-homepage = {
    after    = [ "create-traefik-network.service" ];
    requires = [ "create-traefik-network.service" ];
  };

  virtualisation.oci-containers.containers.homepage = {
    image = "ghcr.io/gethomepage/homepage:latest";
    autoStart = true;
    extraOptions = [
      "--network=traefik"
      "--label=traefik.enable=true"
      "--label=traefik.http.routers.homepage.rule=Host(`${userConfig.domain}`)"
      "--label=traefik.http.routers.homepage.entrypoints=websecure"
      "--label=traefik.http.routers.homepage.tls=true"
      "--label=traefik.http.routers.homepage.tls.certresolver=letsencrypt"
      "--label=traefik.http.services.homepage.loadbalancer.server.port=${toString ports.homepage}"
    ];
    environment = {
      PORT = toString ports.homepage;
      HOMEPAGE_ALLOWED_HOSTS = userConfig.domain;
    };
    volumes = [
      "/var/lib/homepage/config:/app/config"
    ];
  };
}
