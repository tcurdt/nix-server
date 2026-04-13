{ config, pkgs, ... }:
{

  networking.hostName = "utm-x86";
  networking.domain = "utm";
  system.stateVersion = "25.11";

  imports = [

    ../hardware/utm-x86.nix
    ../modules/server.nix
    ../modules/builders.nix
    ../modules/mmdb.nix

    ../users/root.nix
    ../users/ops.nix
    { ops.keyFiles = [ ../keys/tcurdt.pub ]; }

    { users.users.root.password = "secret"; }

    ../modules/nginx.nix
    ../modules/authelia.nix

    ../modules/db-postgres.nix

    ../modules/formcha.nix

    # ../modules/litestream.nix
    # ../modules/db-sqld.nix
    # ../modules/db-spacetimedb.nix
  ];

  my.builders.allow = "remote";

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

  services.my.authelia = {
    domain = "vafer.work";
    external_url = "https://id.vafer.work";
  };

  services.my.nginx = {
    virtualHosts."id.vafer.work" = {
      selfSigned = true;
      locations."/" = {
        proxyPass = config.services.my.authelia.url;
      };
    };
    virtualHosts."formcha.vafer.work" = {
      selfSigned = true;
      authelia = config.services.my.authelia;
      locations."/" = {
        proxyPass = config.services.my.formcha.url;
      };
    };
  };

  services.my.formcha = {
    enable = true;
    envFile = "/secrets/formcha.env";
  };

  # services.my.sqld = {
  #   enable = true;
  #   primary = true; # false for replica
  #   listenAddress = "0.0.0.0";
  #   ports = {
  #     http = 8081;
  #     grpc = 5001;
  #   };
  #   ca = {
  #     cert = "/secrets/sqld_ca_cert.pem";
  #     # key = "/secrets/sqld_ca_key.pem";
  #   };
  #   server = {
  #     cert = "/secrets/sqld_server_cert.pem";
  #     key = "/secrets/sqld_server_key.pem";
  #   };
  #   client = {
  #     key = "/secrets/sqld_client_key.pem";
  #   };
  # };

  # services.my.litestream = {
  #   enable = true;
  #   settings = {
  #     addr = "0.0.0.0:9090";
  #     accessKeyId = "S3_ACCESS_KEY_ID";
  #     secretAccessKey = "S3_SECRET_ACCESS_KEY";
  #     forcePathStyle = true;
  #     endpoint = "S3_ENDPOINT";
  #     logging = {
  #       level = "info";
  #     };
  #     levels = [
  #       { interval = "15m"; }
  #     ];
  #     l0Retention = "30m";
  #     l0RetentionCheckInterval = "5m";
  #     snapshot = {
  #       interval = "24h";
  #       retention = "168h";
  #     };
  #     dbs = [
  #       {
  #         path = "/data/account.sqlite";
  #         monitorInterval = "5s";
  #         checkpointInterval = "5m";
  #         minCheckpointPageCount = 10000;
  #         truncatePageN = 0;
  #         replica = {
  #           url = "s3://BUCKET/litestream/account.sqlite";
  #           syncInterval = "5s";
  #         };
  #       }
  #     ];
  #   };
  # };

  services.my.postgres = {
    enable = true;

    package = pkgs.postgresql_18;

    # listenAddress = "0.0.0.0";
    # port = 5432;

    # psql -h /run/postgres/main -U postgres
    unixSocketDir = "/run/postgres/main";

    databases = [
      "main"
      "foo"
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
