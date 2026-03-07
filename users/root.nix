{
  # config,
  pkgs,
  ...
}:
{
  users.users.root = (import ./default.nix { inherit pkgs; }) // {

    openssh.authorizedKeys.keyFiles = [ ../keys/tcurdt.pub ];

    # password = "secret";
    # promptInitialPassword = true;
    # hashedPassword = "*"; # no password allowed

  };

}
