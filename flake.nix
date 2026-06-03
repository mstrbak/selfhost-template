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
      userConfig  = import ./config.nix;
      stateVersion = "24.11";
      libx = import ./lib { inherit inputs userConfig stateVersion; };
      server = libx.mkNixos { system = "x86_64-linux"; };
    in {
      nixosConfigurations = {
        ${userConfig.hostname} = server;
        # Stable alias so workflows can target `.#default` regardless of hostname.
        default = server;
      };
    };
}
