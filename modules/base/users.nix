{ userConfig, ... }:
{
  users.mutableUsers = false;

  users.users.${userConfig.username} = {
    isNormalUser = true;
    description = userConfig.username;
    extraGroups = [ "wheel" ];
    openssh.authorizedKeys.keys = [ userConfig.sshPublicKey ];
    # Declarative password for VNC console fallback. null = no password (SSH
    # key only). Hashed by the install/deploy workflow via `openssl passwd -6`
    # from the INITIAL_USER_PASSWORD GitHub secret.
    hashedPassword =
      if userConfig.hashedPassword == ""
      then null
      else userConfig.hashedPassword;
  };

  # Passwordless sudo for wheel — required for `nixos-rebuild --use-remote-sudo`
  # from GitHub Actions over Tailscale (no TTY for password prompt). Acceptable
  # because: (a) SSH is key-only, (b) post-lockdown SSH is Tailscale-only.
  security.sudo.wheelNeedsPassword = false;
}
