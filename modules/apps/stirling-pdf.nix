{ pkgs, userConfig, ports, ... }:
{
  systemd.tmpfiles.rules = [
    "d /mnt/appdata/stirling-pdf         0755 root root - -"
    "d /mnt/appdata/stirling-pdf/trainingData  0755 root root - -"
    "d /mnt/appdata/stirling-pdf/extraConfigs  0755 root root - -"
    "d /mnt/appdata/stirling-pdf/customFiles   0755 root root - -"
    "d /mnt/appdata/stirling-pdf/logs    0755 root root - -"
  ];

  systemd.services.docker-stirling-pdf = {
    after    = [ "create-traefik-network.service" ];
    requires = [ "create-traefik-network.service" ];
  };

  virtualisation.oci-containers.containers.stirling-pdf = {
    image = "docker.stirlingpdf.com/stirlingtools/stirling-pdf:latest";
    autoStart = true;
    extraOptions = [
      "--network=traefik"
      "--label=traefik.enable=true"
      "--label=traefik.http.routers.stirling-pdf.rule=Host(`pdf.${userConfig.domain}`)"
      "--label=traefik.http.routers.stirling-pdf.entrypoints=websecure"
      "--label=traefik.http.routers.stirling-pdf.tls=true"
      "--label=traefik.http.routers.stirling-pdf.tls.certresolver=letsencrypt"
      "--label=traefik.http.services.stirling-pdf.loadbalancer.server.port=8080"
    ];
    environment = {
      DOCKER_ENABLE_SECURITY = "false";
      INSTALL_BOOK_AND_ADVANCED_HTML_OPS = "false";
      LANGS = "en_GB";
    };
    volumes = [
      "/mnt/appdata/stirling-pdf/trainingData:/usr/share/tessdata"
      "/mnt/appdata/stirling-pdf/extraConfigs:/configs"
      "/mnt/appdata/stirling-pdf/customFiles:/customFiles"
      "/mnt/appdata/stirling-pdf/logs:/logs"
    ];
  };
}
