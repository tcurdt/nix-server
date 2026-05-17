{
  config,
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

    ../modules/db-postgres.nix

    ../modules/formcha.nix

  ];

  networking.hostId = "feedfeed";

  networking.firewall.allowedTCPPorts = [
    # 53 # dns
    80 # http
    443 # https
  ];

  services.my.mmdb = {
    enable = true;
  };

  services.pocket-id = {
    enable = true;

    settings = {
      APP_URL = "https://id.vafer.org";

      HOST = "127.0.0.1";
      PORT = 1411;

      # UNIX_SOCKET = "";
      # UNIX_SOCKET_MODE = "";

      TRUST_PROXY = true; # honor X-Forwarded-*
      # TRUSTED_PLATFORM = "";

      ALLOW_OWN_ACCOUNT_EDIT = false;

      # sqlite
      DB_CONNECTION_STRING = "/var/lib/pocket-id/pocket-id.db";

      # postgres
      # DB_CONNECTION_STRING = "postgres://pocket-id@/pocket-id?host=/run/postgres/main";

      VERSION_CHECK_DISABLED = true;
      ANALYTICS_DISABLED = true;

      # ENCRYPTION_KEY = "";
      ENCRYPTION_KEY_FILE = "/secrets/pocket-id.key";

      # GEOLITE_DB_PATH = "/var/lib/mmdb/ip66.mmdb";

      # METRICS_ENABLED = true;
    };
    # environmentFile = "/secrets/pocket-id.env";
  };

  services.headscale = {
    enable = true;

    address = "127.0.0.1";
    port = 8080;

    settings = {
      server_url = "https://head.vafer.org";

      dns = {
        base_domain = "tail.vafer.org";
        magic_dns = true;
      };

      # oidc = {
      #   issuer = "https://id.vafer.org";
      #   client_id = "headscale";
      #   client_secret_path = "/secrets/headscale-oidc-client-secret";
      #   allowed_users = [ "tcurdt@vafer.org" ];
      # };

      log.level = "info";
    };
  };

  # sudo -u forgejo forgejo admin user create \
  #   --admin \
  #   --username tcurdt \
  #   --email tcurdt@vafer.org \
  #   --password '<password>' \
  #   --config /var/lib/forgejo/custom/conf/app.ini

  services.forgejo = {
    enable = true;
    lfs.enable = true;

    settings = {
      # DEFAULT.APP_NAME = "vafer.org";

      server = {
        DOMAIN = "git.vafer.org";
        ROOT_URL = "https://git.vafer.org/";
        HTTP_ADDR = "127.0.0.1";
        HTTP_PORT = 3000;
      };

      service = {
        DISABLE_REGISTRATION = true;
      };

      session = {
        COOKIE_SECURE = true;
      };
    };
  };

  services.my.nginx = {
    # virtualHosts."id.vafer.org" = {
    #   selfSigned = true;
    #   # locations."/" = {
    #   #   proxyPass = "http://127.0.0.1:1411";
    #   #   extraConfig = ''
    #   #     proxy_busy_buffers_size 512k;
    #   #     proxy_buffers 4 512k;
    #   #     proxy_buffer_size 256k;
    #   #   '';
    #   # };
    # };
    virtualHosts."head.vafer.org" = {
      selfSigned = true;
      locations."/" = {
        proxyPass = "http://${config.services.headscale.address}:${toString config.services.headscale.port}";
        proxyWebsockets = true;
        extraConfig = ''
          proxy_buffering off;
          proxy_read_timeout 3600s;
        '';
      };
    };
    virtualHosts."git.vafer.org" = {
      selfSigned = true;
      locations."/" = {
        proxyPass = "http://${config.services.forgejo.settings.server.HTTP_ADDR}:${toString config.services.forgejo.settings.server.HTTP_PORT}";
        proxyWebsockets = true;
        extraConfig = ''
          client_max_body_size 512M;
        '';
      };
    };
    # virtualHosts."formcha.vafer.org" = {
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
      log_line_prefix = "%t [%u@%d] "; # timestamp, user, db
    };
  };

  environment.systemPackages = [
    pkgs.postgresql_18 # psql
  ];

}
