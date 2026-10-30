{
  # pkgs,
  # inputs,
  ...
}:
{

  networking.hostName = "k3s-runner";
  system.stateVersion = "26.05";

  imports = [

    ../hardware/hetzner-zfs-efi.nix
    ../modules/server.nix
    {
      # ZFS records pool ownership with the host ID. Keep the shared value so ZFS
      # data can move between these hosts without requiring a forced import.
      networking.hostId = "feedfeed";
    }

    ../modules/users.nix
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

  services.my.k3s-runner = {
    enable = true;
  };

}
