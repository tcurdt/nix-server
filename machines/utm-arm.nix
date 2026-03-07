{
  # pkgs,
  ...
}:
{

  networking.hostName = "utm-arm";
  networking.domain = "utm";
  system.stateVersion = "25.11";

  imports = [

    ../hardware/utm-arm.nix
    ../modules/server.nix

    ../users/root.nix
    ../users/ops.nix
    { ops.keyFiles = [ ../keys/tcurdt.pub ]; }

    { users.users.root.password = "secret"; }

  ];
}
