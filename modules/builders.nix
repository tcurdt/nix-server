{ lib, config, ... }:

let
  cfg = config.my.builders;
in
{
  options.my.builders = {
    enabled = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Allow building from source. Set to false to only use cached substitutes.";
    };
  };

  config = lib.mkIf (!cfg.enabled) {
    nix.settings.max-jobs = lib.mkForce 0;
    nix.settings.builders = lib.mkForce "";
    nix.settings.fallback = lib.mkForce false;

    nix.distributedBuilds = lib.mkForce false;
    nix.buildMachines = lib.mkForce [ ];
  };
}
