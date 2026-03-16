{
  lib,
  config,
  ...
}:

let
  cfg = config.services.my.authelia;
  port = toString cfg.port;
in
{
  options.services.my.authelia = {

    domain = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = "The root domain protected by Authelia (e.g. \"vafer.work\").";
    };

    external_url = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = "The full URL of the Authelia instance (e.g. \"https://id.vafer.work\").";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 9091;
      internal = true;
      description = "Port Authelia listens on.";
    };

    url = lib.mkOption {
      type = lib.types.str;
      internal = true;
      description = "Derived HTTP URL for proxying to Authelia.";
    };

  };

  config = lib.mkIf (cfg.domain != "") {

    services.my.authelia.url = "http://127.0.0.1:${port}";

    services.authelia.instances.main = {
      enable = true;
      secrets = {
        jwtSecretFile = "/secrets/authelia-jwt";
        storageEncryptionKeyFile = "/secrets/authelia-storage";
        sessionSecretFile = "/secrets/authelia-session";
      };
      settings = {
        theme = "dark";
        server.address = "tcp://:${port}/";
        authentication_backend = {
          file.path = "/etc/authelia/users.yml";
          password_reset.disable = true;
        };
        session.cookies = [
          {
            domain = cfg.domain;
            authelia_url = cfg.external_url;
          }
        ];
        storage.local.path = "/var/lib/authelia-main/db.sqlite3";
        notifier.filesystem.filename = "/var/lib/authelia-main/notifications.txt";
        totp = {
          issuer = cfg.domain;
        };
        webauthn = {
          enable_passkey_login = true;
          display_name = cfg.domain;
        };
        access_control = {
          default_policy = "one_factor";
        };
      };
    };

  };
}
