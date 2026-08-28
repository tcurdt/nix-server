{
  # config,
  pkgs,
  # inputs,
  ...
}:
{

  networking.hostName = "michael";
  system.stateVersion = "26.05";

  imports = [

    ../hardware/hetzner-efi.nix
    ../modules/server.nix
    {
      # Strict filtering rejects packets unless their source is reachable through
      # the receiving interface, providing spoof protection for conventional routing.
      boot.kernel.sysctl = {
        "net.ipv4.conf.default.rp_filter" = 1;
        "net.ipv4.conf.all.rp_filter" = 1;
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
    {
      # nix run nixpkgs#mkpasswd -- -m sha-512
      # su - root
      users.users.root.hashedPassword = "$6$/OBNw1chITrkLuVU$sZeOSyjQLGRdcm1DiOtKME8b9.odIJNlfXN8O/zQJL8uWYzUUYNmErApPc4eswfBDiFYHnrcpWuKpAFPZY99d1";
    }

    ../modules/mmdb.nix
    ../modules/nginx.nix
    ../modules/laravel.nix
    ../modules/db-mariadb.nix

  ];

  services.my.mmdb = {
    enable = true;
  };

  services.my.nginx = {
    enable = true;
  };

  services.my.laravel.sites.cc = {
    domains = [ "corpuscoranicum.de" ];
    phpPackage = pkgs.php84;
  };

  services.my.laravel.sites.pc = {
    domains = [ "paleocoran.de" ];
    phpPackage = pkgs.php84;
  };

  # mariadb --socket=/run/mariadb/cc/mysqld.sock -u root
  services.my.mariadb.instances.cc = {
    enable = true;
    package = pkgs.mariadb_118;
    unixSocketDir = "/run/mariadb/cc";
    databases = [ "cc" ];
    settings = {
    };
  };

  # mariadb --socket=/run/mariadb/pc/mysqld.sock -u root
  services.my.mariadb.instances.pc = {
    enable = true;
    package = pkgs.mariadb_118;
    unixSocketDir = "/run/mariadb/pc";
    databases = [ "pc" ];
    settings = {
    };
  };

  environment.systemPackages = [
    pkgs.mariadb_118
  ];

}
