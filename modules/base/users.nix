{ userConfig, ... }:
{
  users.mutableUsers = false;

  users.users.${userConfig.username} = {
    isNormalUser = true;
    description = userConfig.username;
    extraGroups = [ "wheel" ];
    openssh.authorizedKeys.keys = [ userConfig.sshPublicKey ];
  };

  # Passwordless sudo for wheel — required for `nixos-rebuild --use-remote-sudo`
  # from GitHub Actions over Tailscale (no TTY for password prompt). Acceptable
  # because: (a) SSH is key-only, (b) post-lockdown SSH is Tailscale-only.
  security.sudo.wheelNeedsPassword = false;
}
