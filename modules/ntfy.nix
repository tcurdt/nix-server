{
  config,
  lib,
  ...
}:

# https://docs.ntfy.sh/config/

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

    enableLogin = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable web UI login and account management (enable-login).";
    };

    requireLogin = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Deny all unauthenticated access to topics (auth-default-access: deny-all).";
    };

    upstreamBaseUrl = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = "https://ntfy.sh";
      description = "Upstream ntfy.sh URL for iOS push notification forwarding. Null disables forwarding.";
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
        base-url = if cfg.server != null then "https://${cfg.server}" else "http://${listen}";
        behind-proxy = cfg.server != null;
        enable-login = cfg.enableLogin;
        auth-default-access = lib.mkIf cfg.requireLogin "deny-all";
        upstream-base-url = lib.mkIf (cfg.upstreamBaseUrl != null) cfg.upstreamBaseUrl;
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
