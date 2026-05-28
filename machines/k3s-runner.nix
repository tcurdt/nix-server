{
  # pkgs,
  # inputs,
  ...
}:
{

  networking.hostName = "k3s-runner";
  system.stateVersion = "25.11";

  imports = [

    ../hardware/hetzner-efi.nix
    ../modules/server.nix

    ../users/root.nix
    ../users/ops.nix
    { ops.keyFiles = [ ../keys/tcurdt.pub ]; }

    # { users.users.root.password = "secret"; }

    ../modules/mmdb.nix
    ../modules/k3s-runner.nix
  ];

  services.my.mmdb = {
    enable = true;
  };

}
