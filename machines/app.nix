{
  # config,
  pkgs,
  # inputs,
  ...
}:
{

  networking.hostName = "app";
  networking.domain = "nixos";
  system.stateVersion = "25.11";

  imports = [

    ../hardware/hetzner-efi.nix
    ../modules/server.nix

    # ../modules/no-registry.nix
    # ../modules/builders.nix

    ../modules/mmdb.nix

    ../users/root.nix
    ../users/ops.nix
    { ops.keyFiles = [ ../keys/tcurdt.pub ]; }

    { users.users.root.password = "secret"; }

    ../modules/nginx.nix

    ../modules/db-postgres.nix

    ../modules/formcha.nix

  ];

  # my.builders.allow = "remote";

  networking.hostId = "7ec474b0";

  networking.firewall.allowedTCPPorts = [
    # 53 # dns
    80 # http
    443 # https
    # 5432 # postgres
    # 8081 # sqld http
    # 5001 # sqld grpc
  ];

  services.my.mmdb = {
    enable = true;
    # daysBetweenUpdates = 3;
  };

  services.my.nginx = {
    virtualHosts."id.vafer.work" = {
      selfSigned = true;
      # locations."/" = {
      #   proxyPass = config.services.my.authelia.url;
      # };
    };
    # virtualHosts."formcha.vafer.work" = {
    #   selfSigned = true;
    #   # authelia = config.services.my.authelia;
    #   locations."/" = {
    #     proxyPass = config.services.my.formcha.url;
    #   };
    # };
  };

  services.my.formcha = {
    enable = true;
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
      log_line_prefix = "%t [%p] %u@%d "; # timestamp, pid, user, db
    };
  };

  environment.systemPackages = [
    pkgs.postgresql_18 # psql
  ];

}
