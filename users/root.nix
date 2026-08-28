{
  # config,
  pkgs,
  ...
}:
{
  users.users.root = {
    shell = pkgs.bash;

    openssh.authorizedKeys.keyFiles = [ ../keys/tcurdt.pub ];

    # password = "secret";
    # promptInitialPassword = true;
    # hashedPassword = "*"; # no password allowed

  };

}
