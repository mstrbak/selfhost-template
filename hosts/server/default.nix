{ pkgs, userConfig, stateVersion, ... }:
{
  imports = [
    ./hardware-configuration.nix
    ./disko.nix
    ../../modules/base/networking.nix
    ../../modules/base/ssh.nix
    ../../modules/base/tailscale.nix
    ../../modules/base/users.nix
    ../../modules/base/nix.nix
    # infra
    ../../modules/infra/traefik.nix
    ../../modules/infra/homepage.nix
    # apps
    ../../modules/apps/vaultwarden.nix
    ../../modules/apps/immich.nix
    # ../../modules/apps/opencloud.nix    # switched to Nextcloud
    ../../modules/apps/nextcloud.nix
    ../../modules/apps/onlyoffice.nix
    ../../modules/apps/searxng.nix
    ../../modules/apps/excalidraw.nix
    ../../modules/apps/portainer.nix
    ../../modules/apps/ittools.nix
    ../../modules/apps/stirling-pdf.nix
  ];

  # Docker required for OCI containers.
  virtualisation.docker = {
    enable = true;
    autoPrune = { enable = true; dates = "weekly"; };
  };
  virtualisation.oci-containers.backend = "docker";

  system.stateVersion = stateVersion;
  time.timeZone = userConfig.timeZone;
  i18n.defaultLocale = "en_US.UTF-8";

  # Contabo VPS S/M/L use SeaBIOS legacy boot — no UEFI exposed in the panel.
  # GRUB installs into the 1 MiB EF02 BIOS Boot Partition declared in disko.nix.
  # `boot.loader.grub.devices` is set automatically by the disko nixos module
  # from the EF02 partition; setting it again here causes a duplicate-device
  # assertion failure.
  boot.loader = {
    systemd-boot.enable = false;
    efi.canTouchEfiVariables = false;
    grub = {
      enable = true;
      efiSupport = false;
    };
  };

  environment.systemPackages = with pkgs; [
    curl
    git
    htop
    jq
    tree
    vim
    wget
  ];
}
