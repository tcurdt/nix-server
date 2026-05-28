{
  # config,
  pkgs,
  # inputs,
  ...
}:
{

  networking.hostName = "control";
  system.stateVersion = "26.05";

  imports = [

    ../hardware/hetzner-efi.nix
    ../modules/server.nix

    ../users/root.nix
    ../users/ops.nix
    { ops.keyFiles = [ ../keys/tcurdt.pub ]; }

    {
      # create: nix run nixpkgs#mkpasswd -- -m sha-512
      # verify: su - root
      users.users.root.hashedPassword = "$6$/OBNw1chITrkLuVU$sZeOSyjQLGRdcm1DiOtKME8b9.odIJNlfXN8O/zQJL8uWYzUUYNmErApPc4eswfBDiFYHnrcpWuKpAFPZY99d1";
    }

    ../modules/tailscale.nix
    ../modules/mmdb.nix
    ../modules/nginx.nix
    ../modules/oidc.nix
    ../modules/headscale.nix
    ../modules/forgejo.nix
    ../modules/ntfy.nix
    ../modules/grafana.nix
    ../modules/cache-nix.nix
    ../modules/cache-oci.nix
    ../modules/db-postgres.nix
  ];

  services.my.mmdb = {
    enable = true;
  };

  services.my.nginx = {
    enable = true;
  };

  services.my.oidc = {
    server = "id.vafer.org";
  };

  services.my.headscale = {
    server = "head.vafer.org";
    dns = "tail.vafer.org";
    oidc = {
      issuer = "id.vafer.org";
    };
  };

  services.my.tailscale = {
    enable = true;
    server = "head.vafer.org";
  };

  services.my.forgejo = {
    server = "git.vafer.org";
    oidc = {
      issuer = "id.vafer.org";
    };
  };

  services.my.ntfy = {
    enable = true;
    server = "ntfy.vafer.org";
  };

  services.my.grafana = {
    enable = true;
    oidc = {
      issuer = "id.vafer.org";
    };
  };

  services.my.cache-nix = {
    enable = true;
    server = "nix.vafer.org";
  };

  services.my.cache-oci = {
    enable = true;
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
