{ inputs, userConfig, stateVersion, ... }:
let
  helpers = import ./helpers.nix { inherit inputs userConfig stateVersion; };
in {
  inherit (helpers) mkNixos;
}
