{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.my.cache-nix;
  listen = "${cfg.address}:${toString cfg.port}";
in
{
  imports = [
    ./nginx.nix
  ];

  options.services.my.cache-nix = {
    enable = lib.mkEnableOption "Attic Nix binary cache";

    server = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "cache.example.org";
      description = "Public server name for the Attic cache. Null disables nginx registration.";
    };

    address = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      description = "Address atticd listens on.";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 8081;
      description = "Port atticd listens on.";
    };

    environmentFile = lib.mkOption {
      type = lib.types.path;
      default = "/secrets/atticd.env";
      description = ''
        Environment file for atticd secrets. Must provide
        ATTIC_SERVER_TOKEN_RS256_SECRET_BASE64.
      '';
    };

    storagePath = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/atticd/storage";
      description = "Local storage path for Attic cache objects.";
    };

    settings = lib.mkOption {
      type = lib.types.attrsOf lib.types.anything;
      default = { };
      description = "Extra atticd settings merged over the module defaults.";
    };

    url = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      readOnly = true;
      default = if cfg.server == null then null else "https://${cfg.server}/";
      description = "Derived public Attic API endpoint.";
    };
  };

  config = lib.mkIf cfg.enable {
    services.atticd = {
      enable = true;
      package = pkgs.attic-server;
      environmentFile = cfg.environmentFile;
      settings =
        lib.recursiveUpdate
          {
            listen = listen;
            allowed-hosts = lib.optionals (cfg.server != null) [ cfg.server ];
            database.url = "sqlite:///var/lib/atticd/server.db?mode=rwc";
            storage = {
              type = "local";
              path = cfg.storagePath;
            };
          }
          (
            lib.recursiveUpdate (lib.optionalAttrs (cfg.url != null) {
              api-endpoint = cfg.url;
            }) cfg.settings
          );
    };

    services.my.nginx = lib.mkIf (cfg.server != null) {
      enable = true;
      virtualHosts.${cfg.server}.locations."/" = {
        proxyPass = "http://${listen}";
      };
    };
  };
}
