{ inputs, ... }:
{
  imports = [ inputs.user.nixosModules.profiles ];

  programs.bash.enable = true;
  security.sudo.wheelNeedsPassword = false;
  security.sudo.execWheelOnly = true;

  users.mutableUsers = false;
}
