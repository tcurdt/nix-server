{ config, ... }:
{

  networking.hostName = "utm-x86";
  networking.domain = "utm";
  system.stateVersion = "25.11";

  imports = [

    ../hardware/utm-x86.nix
    ../modules/server.nix
    ../modules/mmdb.nix

    ../users/root.nix
    ../users/ops.nix
    { ops.keyFiles = [ ../keys/tcurdt.pub ]; }

    { users.users.root.password = "secret"; }

    ../modules/angie.nix
    ../modules/authelia.nix

    ../modules/db-postgres.nix
    ../modules/db-sqld.nix
    ../modules/db-spacetimedb.nix
    ../modules/formcha.nix
  ];

  networking.firewall.allowedTCPPorts = [
    80 # angie
    443 # angie
    # 5432 # postgres
    8081 # sqld main http
    5001 # sqld main grpc
  ];

  services.my.mmdb = {
    enable = true;
    days = 3;
  };

  services.my.authelia = {
    domain = "vafer.work";
    external_url = "https://id.vafer.work";
  };

  services.my.angie = {
    virtualHosts."id.vafer.work" = {
      selfSigned = true;
      locations."/" = {
        proxyPass = config.services.my.authelia.url;
      };
    };
    virtualHosts."test.vafer.work" = {
      selfSigned = true;
      authelia = config.services.my.authelia;
      locations."/" = {
        proxyPass = config.services.my.formcha.main.url;
      };
    };
  };

  services.my.formcha.main = {
    enable = true;
    envFile = "/secrets/formcha.env";
  };

  services.my.spacetimedb.main = {
    enable = true;
  };

  services.my.sqld.main = {
    enable = true;
    primary = true; # false for replica
    listenAddress = "0.0.0.0";
    ports = {
      http = 8081;
      grpc = 5001;
    };
    ca = {
      cert = "/secrets/sqld_ca_cert.pem";
      # key = "/secrets/sqld_ca_key.pem";
    };
    server = {
      cert = "/secrets/sqld_server_cert.pem";
      key = "/secrets/sqld_server_key.pem";
    };
    client = {
      key = "/secrets/sqld_client_key.pem";
    };
  };

  services.my.postgres.main = {
    enable = true;
    # listenAddress = "0.0.0.0";
    # port = 5432;
    # unixSocket = "/run/postgres/main.sock";
    # databases = [ "main" ];
  };
}
