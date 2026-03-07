{
  # config,
  pkgs,
  inputs,
  ...
}:
{
  users.users.tcurdt = (import ./default.nix { inherit pkgs; }) // {

    openssh.authorizedKeys.keyFiles = [ ../keys/tcurdt.pub ];

    isNormalUser = true;
    extraGroups = [
      "wheel"
      "docker"
    ];
    hashedPassword = "*"; # no password allowed

  };

  home-manager.users.tcurdt = {
    imports = [ inputs.home.homeManagerModules.tcurdt ];
    home.username = "tcurdt";
    home.homeDirectory = "/home/tcurdt";
  };

}
