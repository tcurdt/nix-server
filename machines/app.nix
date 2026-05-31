{
  # config,
  # pkgs,
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

    ../modules/mmdb.nix
    ../modules/nginx.nix
    ../modules/tailscale.nix
    ../modules/headscale.nix
    ../modules/oidc.nix
    ../modules/ntfy.nix
    ../modules/formcha.nix
    # ../modules/db-postgres.nix

  ];

  services.my.mmdb = {
    enable = true;
  };

  services.my.nginx = {
    enable = true;
  };

  # /secrets/tailscale.key
  services.my.tailscale = {
    enable = true;
    server = "head.vafer.org";
  };

  # /secrets/headscale-oidc-client-secret
  services.my.headscale = {
    server = "head.vafer.org";
    domain = "tail.vafer.org";
    oidc = {
      issuer = "id.vafer.org";
    };
  };

  # /secrets/pocket-id.key
  services.my.oidc = {
    server = "id.vafer.org";
  };

  services.my.ntfy = {
    enable = true;
    server = "ntfy.vafer.org";
    # settings = {
    #   auth-users = [
    #     # nix run nixpkgs#htpasswd -- -bnBC 10 "" password | tr -d ':\n'
    #     "admin:$2b$10$tBJLEcQBCyZwDCnWieGjIO8iIKTBQFZ8aignr9e.gwRGrN/qKwmOS:admin"
    #   ];
    #   auth-tokens = [
    #     "admin:tk_ig20coxskv6uhxuaecaawcry2nk5l"
    #   ];
    # };
  };

  # /secrets/formcha-altcha-hmac-key
  services.my.formcha = {
    enable = true;
    server = "formcha.vafer.org";
    # ntfy = {
    #   url = "https://ntfy.vafer.org/formcha";
    #   tokenFile = "/secrets/ntfy-token";
    # };
  };

  # services.my.postgres = {
  #   enable = true;

  #   package = pkgs.postgresql_18;

  #   # listenAddress = "0.0.0.0";
  #   # port = 5432;

  #   # psql -h /run/postgres/main -U postgres
  #   unixSocketDir = "/run/postgres/main";

  #   databases = [
  #     # "foo"
  #     # "bar"
  #   ];

  #   settings = {
  #     shared_buffers = "256MB";
  #     effective_cache_size = "1GB";
  #     work_mem = "4MB";
  #     shared_preload_libraries = "pg_stat_statements";
  #     log_connections = true; # log connections
  #     log_min_duration_statement = 500; # log slow queries
  #     log_statement = "ddl"; # log schema changes
  #     log_duration = false; # keep it in a single log line
  #     log_line_prefix = "%t [%u@%d] "; # timestamp, user, db
  #   };
  # };

  # environment.systemPackages = [
  #   pkgs.postgresql_18 # psql
  # ];

}
