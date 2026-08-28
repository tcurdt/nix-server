{
  # pkgs,
  # inputs,
  ...
}:
{

  networking.hostName = "k3s-server";
  system.stateVersion = "26.05";

  imports = [

    ../hardware/hetzner-efi.nix
    ../modules/server.nix
    {
      # Loose filtering validates source routes while allowing the asymmetric paths
      # used by K3s overlay networking.
      boot.kernel.sysctl = {
        "net.ipv4.conf.default.rp_filter" = 2;
        "net.ipv4.conf.all.rp_filter" = 2;
      };

      # ZFS records pool ownership with the host ID. Keep the shared value so ZFS
      # data can move between these hosts without requiring a forced import.
      networking.hostId = "feedfeed";
      boot.zfs.forceImportRoot = false;
    }
    ../modules/users.nix

    ../users/root.nix
    ../users/ops.nix
    { ops.keyFiles = [ ../keys/tcurdt.pub ]; }
    # { users.users.root.password = "secret"; }

    ../modules/mmdb.nix
    ../modules/k3s-server.nix
  ];

  services.my.mmdb = {
    enable = true;
  };

  services.my.k3s-server = {
    enable = true;
    # floating-ip = {
    #   enable = true;
    #   ipv4 = "116.202.2.78";
    #   ipv6 = "2a01:4f8:1c17:800f::1";
    #   ipv6Gateway = "fe80::1";
    #   interface = "enp1s0";
    # };
  };

}
