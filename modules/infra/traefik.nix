{ config, pkgs, userConfig, ports, ... }:
let
  traefikYml = pkgs.writeText "traefik.yml" ''
    api:
      dashboard: true
      insecure: false

    entryPoints:
      web:
        address: ":80"
        http:
          redirections:
            entryPoint:
              to: websecure
              scheme: https
      websecure:
        address: ":443"
        transport:
          respondingTimeouts:
            readTimeout: 0
            writeTimeout: 0
            idleTimeout: 600s

    certificatesResolvers:
      letsencrypt:
        acme:
          email: ${userConfig.acmeEmail}
          storage: /letsencrypt/acme.json
          dnsChallenge:
            provider: cloudflare
            resolvers:
              - "1.1.1.1:53"
              - "1.0.0.1:53"

    providers:
      docker:
        exposedByDefault: false
        network: traefik
      file:
        directory: /etc/traefik/dynamic
        watch: true

    log:
      level: INFO
  '';

  dynamicWildcardYml = pkgs.writeText "wildcard.yml" ''
    tls:
      stores:
        default:
          defaultGeneratedCert:
            resolver: letsencrypt
            domain:
              main: "${userConfig.domain}"
              sans:
                - "*.${userConfig.domain}"
  '';
in
{
  # Cloudflare DNS-01 token path. Token contents are NOT managed by Nix; they
  # are written out-of-band (see todo/08-secrets-management.md). For now create
  # the file as an empty placeholder so Traefik can start; replace contents
  # via SSH after first deploy.
  systemd.tmpfiles.rules = [
    "d /var/lib/traefik           0750 root root - -"
    "d /var/lib/traefik/letsencrypt 0700 root root - -"
    "d /etc/traefik/dynamic       0755 root root - -"
    "f /var/lib/traefik/cf-token  0400 root root - -"
  ];

  environment.etc."traefik/dynamic/wildcard.yml".source = dynamicWildcardYml;

  systemd.services.create-traefik-network = {
    description = "Create Docker network for Traefik";
    wantedBy = [ "multi-user.target" ];
    after  = [ "docker.service" ];
    requires = [ "docker.service" ];
    before = [ "docker-traefik.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${pkgs.docker}/bin/docker network create traefik || true";
    };
  };

  virtualisation.oci-containers.containers.traefik = {
    image = "traefik:v3.1";
    autoStart = true;
    extraOptions = [
      "--network=traefik"
      # Publish only on the host; firewall keeps 80/443 closed publicly,
      # tailscale0 is trusted, so only tailnet clients can reach Traefik.
      "--publish=${toString ports.traefikHttp}:80"
      "--publish=${toString ports.traefikHttps}:443"
    ];
    environmentFiles = [ "/var/lib/traefik/cf-token" ];
    volumes = [
      "${traefikYml}:/etc/traefik/traefik.yml:ro"
      "/etc/traefik/dynamic:/etc/traefik/dynamic:ro"
      "/var/lib/traefik/letsencrypt:/letsencrypt"
      "/var/run/docker.sock:/var/run/docker.sock:ro"
    ];
  };
}
