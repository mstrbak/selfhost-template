{ pkgs, userConfig, ports, ... }:
let
  image = "opencloudeu/opencloud-rolling:latest";

  # Extends OpenCloud's default Content-Security-Policy so the WOPI editor
  # (OnlyOffice on office.<domain>) can be embedded as an iframe.
  # Reference for csp.yaml structure + ocis setup:
  #   https://thomaswildetech.com/blog/2025/04/23/setting-up-owncloud-infinite-scale-ocis/
  cspYaml = pkgs.writeText "csp.yaml" ''
    directives:
      child-src:
        - 'self'
      connect-src:
        - 'self'
      default-src:
        - 'none'
      font-src:
        - 'self'
      frame-ancestors:
        - 'self'
      frame-src:
        - 'self'
        - blob:
        - https://embed.diagrams.net/
        - https://office.${userConfig.domain}
      img-src:
        - 'self'
        - data:
        - blob:
      manifest-src:
        - 'self'
      media-src:
        - 'self'
      object-src:
        - 'self'
        - blob:
      script-src:
        - 'self'
        - 'unsafe-inline'
        - 'unsafe-eval'
      style-src:
        - 'self'
        - 'unsafe-inline'
  '';
in
{
  systemd.tmpfiles.rules = [
    "d /mnt/appdata/opencloud         0755 root root - -"
    "d /mnt/appdata/opencloud/config  0755 root root - -"
    "d /mnt/appdata/opencloud/data    0755 root root - -"
    # PosixFS storage root — user spaces live here as real folders.
    "d /mnt/storage/opencloud         0755 root root - -"
    # Env file written by deploy workflow (SERVICES_PASSWORD → IDM_ADMIN_PASSWORD).
    # Mode 0644 because the init container reads it through `--env-file` and
    # may run as a non-root UID; 0400 root-only would break the init step.
    "f /mnt/appdata/opencloud/env     0644 root root - -"
  ];

  # OpenCloud requires `opencloud init` to generate /etc/opencloud/opencloud.yaml
  # before `opencloud server` will start. Idempotent: skips if the file exists.
  systemd.services.opencloud-init = {
    description = "OpenCloud one-shot init (config generation)";
    wantedBy = [ "multi-user.target" ];
    before   = [ "docker-opencloud.service" ];
    after    = [ "docker.service" "create-traefik-network.service" ];
    requires = [ "docker.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      if [ -f /mnt/appdata/opencloud/config/opencloud.yaml ]; then
        echo "OpenCloud already initialized; skipping."
        exit 0
      fi
      if [ ! -s /mnt/appdata/opencloud/env ]; then
        # First-boot ordering: env file is written by the deploy workflow's
        # secret-push step, which runs AFTER nixos-rebuild. Exit success here
        # and rely on the deploy workflow restarting this unit afterwards.
        echo "OpenCloud env file empty; deferring init until secrets pushed."
        exit 0
      fi
      # `opencloud init` prompts interactively for "insecure mode?" — answer no.
      # `-i` attaches stdin so the piped "no" reaches the binary.
      printf 'no\n' | ${pkgs.docker}/bin/docker run --rm -i \
        --user=0:0 \
        -v /mnt/appdata/opencloud/config:/etc/opencloud \
        --env-file /mnt/appdata/opencloud/env \
        ${image} init
    '';
  };

  systemd.services.docker-opencloud = {
    after    = [ "create-traefik-network.service" "opencloud-init.service" ];
    requires = [ "create-traefik-network.service" "opencloud-init.service" ];
  };

  virtualisation.oci-containers.containers.opencloud = {
    inherit image;
    autoStart = true;
    cmd = [ "server" ];
    extraOptions = [
      "--network=traefik"
      # OpenCloud's proxy fetches its OWN /.well-known/openid-configuration
      # at the public URL to verify access tokens. Traefik claims a
      # `--network-alias=cloud.<domain>` so Docker's embedded DNS resolves
      # the public hostname to Traefik's container IP within this network —
      # avoiding the host-gateway loop through the docker0/iptables NAT.
      # Run as root inside the container so bind-mounted host dirs are
      # readable+writable regardless of host UID. Acceptable for a homelab
      # single-host setup.
      "--user=0:0"
      "--label=traefik.enable=true"
      "--label=traefik.http.routers.opencloud.rule=Host(`cloud.${userConfig.domain}`)"
      "--label=traefik.http.routers.opencloud.entrypoints=websecure"
      "--label=traefik.http.routers.opencloud.tls=true"
      "--label=traefik.http.routers.opencloud.tls.certresolver=letsencrypt"
      "--label=traefik.http.services.opencloud.loadbalancer.server.port=${toString ports.opencloud}"
    ];
    environment = {
      OC_URL                = "https://cloud.${userConfig.domain}";
      OC_LOG_LEVEL          = "info";
      OC_INSECURE           = "false";
      # Proxy listens plain HTTP on :9200 — Traefik in front terminates TLS.
      # Without this, OpenCloud listens HTTPS with a self-signed cert and
      # Traefik's HTTP backend call fails with "client sent HTTP to HTTPS server".
      PROXY_TLS             = "false";
      # Admin identity — password supplied via env file.
      IDM_ADMIN_USERNAME    = "admin";
      IDM_CREATE_DEMO_USERS = "false";
      # PosixFS storage driver — users' spaces are real folders under
      # STORAGE_USERS_POSIX_ROOT. Lets you put files there from the host
      # (or Immich, OpenCloud sync, etc.) and have them appear in the UI.
      STORAGE_USERS_DRIVER            = "posix";
      # Dedicated subdir so OpenCloud's PosixFS layout doesn't collide with
      # Immich's /mnt/storage/photos tree. After init you can bind-mount
      # /mnt/storage/photos into a user's space dir (see README).
      STORAGE_USERS_POSIX_ROOT        = "/mnt/storage/opencloud";
      STORAGE_USERS_ID_CACHE_STORE    = "nats-js-kv";
      # `inotify`-based watch so files added externally are picked up live.
      STORAGE_USERS_POSIX_WATCH_FS    = "true";

      # OnlyOffice (collaborative office editor) WOPI integration.
      # Single-binary deploy does NOT start collaboration service by default —
      # opt-in plus gateway + app-registry it depends on.
      OC_ADD_RUN_SERVICES             = "gateway,app-registry,collaboration";
      COLLABORATION_APP_NAME          = "OnlyOffice";
      COLLABORATION_APP_PRODUCT       = "OnlyOffice";
      COLLABORATION_APP_DESCRIPTION   = "OnlyOffice in-browser office editor";
      COLLABORATION_APP_ICON          = "image-edit";
      COLLABORATION_APP_ADDR          = "https://office.${userConfig.domain}";
      COLLABORATION_APP_INSECURE      = "false";
      # WOPI_SRC = URL OnlyOffice uses to call back to OpenCloud's WOPI bridge.
      # For single-binary deploy with one external URL we reuse OC_URL.
      COLLABORATION_WOPI_SRC          = "https://cloud.${userConfig.domain}";
      COLLABORATION_CS3API_DATAGATEWAY_INSECURE = "false";
      # Custom CSP file extending frame-src to include OnlyOffice.
      PROXY_CSP_CONFIG_FILE_LOCATION = "/var/lib/opencloud/csp.yaml";
      # JWT secret to talk to OnlyOffice — same as OnlyOffice's JWT_SECRET.
      # Supplied to OpenCloud via env file (reuses SERVICES_PASSWORD).
    };
    environmentFiles = [ "/mnt/appdata/opencloud/env" ];
    volumes = [
      "/mnt/appdata/opencloud/config:/etc/opencloud"
      "/mnt/appdata/opencloud/data:/var/lib/opencloud"
      # OpenCloud reads/writes user data on shared storage (Immich also uses this).
      "/mnt/storage:/mnt/storage"
      # Custom CSP file (Nix-generated, read-only).
      "${cspYaml}:/var/lib/opencloud/csp.yaml:ro"
    ];
  };
}
