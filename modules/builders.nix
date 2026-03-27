{ lib, config, ... }:

let
  cfg = config.my.builders;
in
{
  options.my.builders = {
    allow = lib.mkOption {
      type = lib.types.enum [
        "all"
        "remote"
        "none"
      ];
      default = "all";
      description = "Control where builds are allowed: all (local/remote), remote (only remote builders), none (no builds on this machine).";
    };
  };

  config = lib.mkMerge [
    (lib.mkIf (cfg.allow == "remote") {
      nix.settings.fallback = lib.mkForce false;
      nix.settings.substitute = lib.mkForce true;
      nix.distributedBuilds = lib.mkForce true;
      # nix.buildMachines = lib.mkForce [ ]; # should realistically not be empty, but not enforced
    })

    (lib.mkIf (cfg.allow == "none") {
      nix.settings.fallback = lib.mkForce false;
      nix.settings.substitute = lib.mkForce true;
      nix.distributedBuilds = lib.mkForce false;
      nix.buildMachines = lib.mkForce [ ];
    })
  ];
}
