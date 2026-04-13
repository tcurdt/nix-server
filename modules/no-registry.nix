{ lib, ... }:
{
  nixpkgs.flake.setFlakeRegistry = false;
  nixpkgs.flake.setNixPath = false;

  nix.registry = lib.mkForce { };
  nix.settings.flake-registry = lib.mkForce "";
  nix.nixPath = lib.mkForce [ ];
}
