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
    users.users.ops = {
      profile = import inputs.user.profile.tcurdt;
      shell = pkgs.bash;

      openssh.authorizedKeys.keyFiles = cfg.keyFiles;

      isNormalUser = true;
      extraGroups = [
        "wheel"
        "docker"
      ];
      hashedPassword = "*"; # no password allowed

    };
  };
}
