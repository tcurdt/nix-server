{
  config,
  pkgs,
  lib,
  inputs,
  ...
}:
let
  inherit (lib) mkOption;
  cfg = config.ops;
in
{

  options = {
    ops = {
      keyFiles = mkOption {
        default = [ ];
        description = "...";
      };
    };
  };

  config = {
    users.users.ops = (import ./default.nix { inherit pkgs; }) // {

      openssh.authorizedKeys.keyFiles = cfg.keyFiles;

      isNormalUser = true;
      extraGroups = [
        "wheel"
        "docker"
      ];
      hashedPassword = "*"; # no password allowed

    };

    home-manager.users.ops = {
      imports = [ inputs.home.homeManagerModules.tcurdt ];
      home.username = "ops";
      home.homeDirectory = "/home/ops";
    };
  };
}
