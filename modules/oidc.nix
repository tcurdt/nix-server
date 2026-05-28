{
  config,
  lib,
  ...
}:

let
  cfg = config.services.my.oidc;
in
{
  options.services.my.oidc = {
    server = lib.mkOption {
      type = lib.types.str;
      default = "";
      example = "id.example.org";
      description = "Public Pocket ID / OIDC server name. Empty disables the service.";
    };

    address = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      description = "Address Pocket ID listens on.";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 1411;
      description = "Port Pocket ID listens on.";
    };

    # sudo sh -c 'openssl rand -hex 32 | tr -d "\n" > /secrets/pocket-id.key'
    encryptionKeyFile = lib.mkOption {
      type = lib.types.str;
      default = "/secrets/pocket-id.key";
      description = "File containing the Pocket ID encryption key.";
    };

    databaseConnectionString = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/pocket-id/pocket-id.db";
      description = "Pocket ID database connection string.";
    };

    extraSettings = lib.mkOption {
      type = lib.types.attrsOf lib.types.anything;
      default = { };
      description = "Extra Pocket ID settings merged over the module defaults.";
    };

    url = lib.mkOption {
      type = lib.types.str;
      readOnly = true;
      default = "https://${cfg.server}";
      description = "Derived public OIDC URL.";
    };
  };

  config = lib.mkIf (cfg.server != "") {
    services.pocket-id = {
      enable = true;

      settings = {
        APP_URL = cfg.url;
        HOST = cfg.address;
        PORT = cfg.port;
        TRUST_PROXY = true;
        ALLOW_OWN_ACCOUNT_EDIT = false;
        DB_CONNECTION_STRING = cfg.databaseConnectionString;
        VERSION_CHECK_DISABLED = true;
        ANALYTICS_DISABLED = true;
        ENCRYPTION_KEY_FILE = cfg.encryptionKeyFile;
      }
      // cfg.extraSettings;
    };

    services.my.nginx.virtualHosts.${cfg.server}.locations."/" = {
      proxyPass = "http://${cfg.address}:${toString cfg.port}";
      extraConfig = ''
        proxy_busy_buffers_size 512k;
        proxy_buffers 4 512k;
        proxy_buffer_size 256k;
      '';
    };

  };
}
