{
  description = "NixOS self-host template for Contabo VPS — Tailscale-only, deployed via GitHub Actions";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixos-anywhere = {
      url = "github:nix-community/nixos-anywhere";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, disko, ... }@inputs:
    let
      # Non-sensitive defaults committed to the repo.
      base = import ./config.nix;
      # Sensitive overrides injected by GitHub Actions (gitignored). Falls back
      # to placeholders so `nix flake check` works locally without secrets.
      overrides =
        if builtins.pathExists ./config.local.nix
        then import ./config.local.nix
        else {
          hostname       = "myserver";
          username       = "admin";
          domain         = "example.com";
          acmeEmail      = "you@example.com";
          tailnet        = "tail0000.ts.net";
          sshPublicKey   = "ssh-ed25519 AAAA_PLACEHOLDER you@laptop";
          hashedPassword = "";
          vpsIp          = "0.0.0.0";
          vpsPrefix      = 24;
          vpsGateway     = "0.0.0.1";
        };
      userConfig   = base // overrides;
      stateVersion = "24.11";
      libx   = import ./lib { inherit inputs userConfig stateVersion; };
      server = libx.mkNixos { system = "x86_64-linux"; };
    in {
      nixosConfigurations = {
        ${userConfig.hostname} = server;
        # Stable alias so workflows can target `.#default` regardless of hostname.
        default = server;
      };
    };
}
