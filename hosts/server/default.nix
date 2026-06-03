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

  boot.loader = {
    systemd-boot.enable = true;
    efi.canTouchEfiVariables = true;
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
