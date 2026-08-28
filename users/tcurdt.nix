{
  # config,
  pkgs,
  inputs,
  ...
}:
{
  users.users.tcurdt = {
    profile = import inputs.user.profile.tcurdt;
    shell = pkgs.bash;

    openssh.authorizedKeys.keyFiles = [ ../keys/tcurdt.pub ];

    isNormalUser = true;
    extraGroups = [
      "wheel"
      "docker"
    ];
    hashedPassword = "*"; # no password allowed

  };
}
