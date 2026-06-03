{ pkgs, userConfig, ports, ... }:
{
  systemd.tmpfiles.rules = [
    "d /mnt/appdata/portainer 0700 root root - -"
  ];

  systemd.services.docker-portainer = {
    after    = [ "create-traefik-network.service" ];
    requires = [ "create-traefik-network.service" ];
  };

  virtualisation.oci-containers.containers.portainer = {
    image = "portainer/portainer-ce:latest";
    autoStart = true;
    extraOptions = [
      "--network=traefik"
      "--label=traefik.enable=true"
      "--label=traefik.http.routers.portainer.rule=Host(`portainer.${userConfig.domain}`)"
      "--label=traefik.http.routers.portainer.entrypoints=websecure"
      "--label=traefik.http.routers.portainer.tls=true"
      "--label=traefik.http.routers.portainer.tls.certresolver=letsencrypt"
      "--label=traefik.http.services.portainer.loadbalancer.server.port=${toString ports.portainer}"
    ];
    volumes = [
      "/var/run/docker.sock:/var/run/docker.sock"
      "/mnt/appdata/portainer:/data"
    ];
  };
}
