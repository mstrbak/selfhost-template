{ ... }:
{
  nix = {
    settings = {
      experimental-features = [ "nix-command" "flakes" ];
      auto-optimise-store = true;
      warn-dirty = false;
      trusted-users = [ "root" "@wheel" ];
      # 500MB download buffer for big closures over Tailscale.
      download-buffer-size = 500000000;
    };
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 7d";
    };
  };

  nixpkgs.config.allowUnfree = true;

  # Package list lives in hosts/server/default.nix.
}
