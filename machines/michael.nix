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

    ../hardware/hetzner-zfs-bios.nix
    ../modules/server.nix

    ../modules/users.nix
    ../users/root.nix
    ../users/tcurdt.nix
    # { users.users.root.password = "secret"; }
    {
      # create: nix run nixpkgs#mkpasswd -- -m sha-512
      # verify: su - root
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
