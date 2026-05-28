{
  # config,
  pkgs,
  # inputs,
  ...
}:
{

  networking.hostName = "app";
  system.stateVersion = "26.05";

  imports = [

    ../hardware/hetzner-efi.nix
    ../modules/server.nix

    ../users/root.nix
    ../users/ops.nix
    { ops.keyFiles = [ ../keys/tcurdt.pub ]; }

    # { users.users.root.password = "secret"; }
    {
      # nix run nixpkgs#mkpasswd -- -m sha-512
      # su - root
      users.users.root.hashedPassword = "$6$/OBNw1chITrkLuVU$sZeOSyjQLGRdcm1DiOtKME8b9.odIJNlfXN8O/zQJL8uWYzUUYNmErApPc4eswfBDiFYHnrcpWuKpAFPZY99d1";
    }

    ../modules/tailscale.nix
    ../modules/mmdb.nix
    ../modules/nginx.nix
    ../modules/ntfy.nix
    ../modules/oidc.nix
    ../modules/formcha.nix
    ../modules/db-postgres.nix

  ];

  services.my.mmdb = {
    enable = true;
  };

  services.my.tailscale = {
    enable = true;
    server = "head.vafer.org";
  };

  services.my.nginx = {
    enable = true;
  };

  services.my.oidc = {
    server = "id.vafer.org";
  };

  services.my.ntfy = {
    enable = true;
    server = "ntfy.vafer.org";
  };

  services.my.formcha = {
    enable = true;
    server = "formcha.vafer.org";
    envFile = "/secrets/formcha.env";
  };

  services.my.postgres = {
    enable = true;

    package = pkgs.postgresql_18;

    # listenAddress = "0.0.0.0";
    # port = 5432;

    # psql -h /run/postgres/main -U postgres
    unixSocketDir = "/run/postgres/main";

    databases = [
      # "foo"
      # "bar"
    ];

    settings = {
      shared_buffers = "256MB";
      effective_cache_size = "1GB";
      work_mem = "4MB";
      shared_preload_libraries = "pg_stat_statements";
      log_connections = true; # log connections
      log_min_duration_statement = 500; # log slow queries
      log_statement = "ddl"; # log schema changes
      log_duration = false; # keep it in a single log line
      log_line_prefix = "%t [%u@%d] "; # timestamp, user, db
    };
  };

  environment.systemPackages = [
    pkgs.postgresql_18 # psql
  ];

}
