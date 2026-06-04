{ pkgs, userConfig, ports, ... }:
let
  settings = pkgs.writeText "homepage-settings.yaml" ''
    title: ${userConfig.hostname}
    theme: dark
    color: slate
    useEqualHeights: true
    statusStyle: dot
    headerStyle: clean
    layout:
      Productivity:
        style: row
        columns: 4
        icon: mdi-briefcase-outline
      Media:
        style: row
        columns: 3
        icon: mdi-play-circle-outline
      Tools:
        style: row
        columns: 3
        icon: mdi-tools
      Infrastructure:
        style: row
        columns: 3
        icon: mdi-server-outline
  '';

  services = pkgs.writeText "homepage-services.yaml" ''
    - Productivity:
        - Vaultwarden:
            href: https://pwdman.${userConfig.domain}
            description: Password manager
            icon: bitwarden.svg
        - Nextcloud:
            href: https://cloud.${userConfig.domain}
            description: Files & collaboration
            icon: nextcloud.svg
        - OnlyOffice:
            href: https://office.${userConfig.domain}
            description: Office editor (used by OpenCloud)
            icon: mdi-file-document-edit-outline
        - Excalidraw:
            href: https://draw.${userConfig.domain}
            description: Whiteboard & diagrams
            icon: mdi-draw
        - Penpot:
            href: https://design.${userConfig.domain}
            description: Design & prototyping
            icon: penpot.svg

    - Media:
        - Immich:
            href: https://photos.${userConfig.domain}
            description: Photo library
            icon: immich.svg

    - Tools:
        - SearXNG:
            href: https://search.${userConfig.domain}
            description: Private metasearch
            icon: searxng.svg
        - IT Tools:
            href: https://tools.${userConfig.domain}
            description: Developer utilities
            icon: it-tools.svg
        - Stirling PDF:
            href: https://pdf.${userConfig.domain}
            description: PDF manipulation
            icon: stirling-pdf.svg

    - Infrastructure:
        - Portainer:
            href: https://portainer.${userConfig.domain}
            description: Docker container manager
            icon: portainer.svg
        - Traefik:
            href: https://${userConfig.domain}
            description: Reverse proxy (this host)
            icon: traefik.svg
  '';

  widgets = pkgs.writeText "homepage-widgets.yaml" ''
    - datetime:
        text_size: 2xl
        format:
          dateStyle: long
          timeStyle: short
          hour12: false
    - search:
        provider: custom
        url: https://search.${userConfig.domain}/search?q=
        target: _blank
        showSearchSuggestions: false
    - resources:
        backend: resources
        expanded: true
        cpu: true
        memory: true
        disk: /
  '';

  bookmarks = pkgs.writeText "homepage-bookmarks.yaml" "[]";

  dockerCfg = pkgs.writeText "homepage-docker.yaml" ''
    my-server:
      socket: /var/run/docker.sock
  '';
in
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
      "/var/run/docker.sock:/var/run/docker.sock:ro"
      "${settings}:/app/config/settings.yaml:ro"
      "${services}:/app/config/services.yaml:ro"
      "${widgets}:/app/config/widgets.yaml:ro"
      "${bookmarks}:/app/config/bookmarks.yaml:ro"
      "${dockerCfg}:/app/config/docker.yaml:ro"
    ];
  };
}
