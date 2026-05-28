{
  config,
  lib,
  ...
}:

let
  cfg = config.services.my.ntfy;
  listen = "${cfg.address}:${toString cfg.port}";
in
{
  options.services.my.ntfy = {
    enable = lib.mkEnableOption "ntfy";

    server = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "ntfy.example.org";
      description = "Public server name for ntfy. Null disables nginx registration.";
    };

    address = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      description = "Address ntfy listens on.";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 2586;
      description = "Port ntfy listens on.";
    };

    settings = lib.mkOption {
      type = lib.types.attrsOf lib.types.anything;
      default = { };
      description = "Extra ntfy-sh settings merged over the module defaults.";
    };

    url = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      readOnly = true;
      default = if cfg.server == null then null else "https://${cfg.server}";
      description = "Derived public ntfy URL.";
    };
  };

  config = lib.mkIf cfg.enable {
    services.ntfy-sh = {
      enable = true;
      settings = {
        listen-http = listen;
        base-url = if cfg.url != null then cfg.url else "http://${listen}";
      }
      // cfg.settings;
    };

    services.my.nginx = lib.mkIf (cfg.server != null) {
      enable = true;
      virtualHosts.${cfg.server}.locations."/" = {
        proxyPass = "http://${listen}";
        proxyWebsockets = true;
      };
    };
  };
}
