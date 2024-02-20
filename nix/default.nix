{ system ? builtins.currentSystem
, nixpkgs
, gitignore-nix-src
, isFlakes ? false
}:
let
  overlay = import ./overlay.nix { inherit isFlakes gitignore-nix-src; };
in
import nixpkgs {
  overlays = [ overlay ];
  # broken is needed for hindent to build
  config = { allowBroken = true; };
  inherit system;
}
