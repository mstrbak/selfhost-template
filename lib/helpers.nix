{ inputs, userConfig, stateVersion, ... }:
{
  mkNixos = { system, extraModules ? [] }:
    let
      pkgs  = import inputs.nixpkgs { inherit system; config.allowUnfree = true; };
      ports = import ./ports.nix;
    in
    inputs.nixpkgs.lib.nixosSystem {
      inherit system;
      specialArgs = { inherit pkgs inputs system userConfig ports stateVersion; };
      modules = [
        inputs.disko.nixosModules.disko
        ../hosts/server
      ] ++ extraModules;
    };
}
