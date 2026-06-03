{ pkgs, userConfig, ports, ... }:
{
  systemd.services.docker-excalidraw = {
    after    = [ "create-traefik-network.service" ];
    requires = [ "create-traefik-network.service" ];
  };

  virtualisation.oci-containers.containers.excalidraw = {
    image = "excalidraw/excalidraw:latest";
    autoStart = true;
    extraOptions = [
      "--network=traefik"
      "--label=traefik.enable=true"
      "--label=traefik.http.routers.excalidraw.rule=Host(`draw.${userConfig.domain}`)"
      "--label=traefik.http.routers.excalidraw.entrypoints=websecure"
      "--label=traefik.http.routers.excalidraw.tls=true"
      "--label=traefik.http.routers.excalidraw.tls.certresolver=letsencrypt"
      "--label=traefik.http.services.excalidraw.loadbalancer.server.port=80"
    ];
  };
}
