{ pkgs, userConfig, ports, ... }:
{
  systemd.services.docker-ittools = {
    after    = [ "create-traefik-network.service" ];
    requires = [ "create-traefik-network.service" ];
  };

  virtualisation.oci-containers.containers.ittools = {
    image = "corentinth/it-tools:latest";
    autoStart = true;
    extraOptions = [
      "--network=traefik"
      "--label=traefik.enable=true"
      "--label=traefik.http.routers.ittools.rule=Host(`tools.${userConfig.domain}`)"
      "--label=traefik.http.routers.ittools.entrypoints=websecure"
      "--label=traefik.http.routers.ittools.tls=true"
      "--label=traefik.http.routers.ittools.tls.certresolver=letsencrypt"
      "--label=traefik.http.services.ittools.loadbalancer.server.port=80"
    ];
  };
}
