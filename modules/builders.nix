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
      nix.settings.max-jobs = lib.mkForce 0;
      nix.settings.fallback = lib.mkForce false;
      nix.distributedBuilds = lib.mkForce (config.nix.buildMachines != [ ]);
    })

    (lib.mkIf (cfg.allow == "none") {
      nix.settings.max-jobs = lib.mkForce 0;
      nix.settings.builders = lib.mkForce "";
      nix.settings.fallback = lib.mkForce false;

      nix.distributedBuilds = lib.mkForce false;
      nix.buildMachines = lib.mkForce [ ];
    })
  ];
}
