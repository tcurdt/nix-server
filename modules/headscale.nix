{
  config,
  lib,
  ...
}:

let
  cfg = config.services.my.headscale;
  oidcIssuer = if cfg.oidc.issuer == "" then "" else "https://${cfg.oidc.issuer}";
in
{
  options.services.my.headscale = {
    server = lib.mkOption {
      type = lib.types.str;
      default = "";
      example = "head.example.org";
      description = "Public Headscale server name. Empty disables the service.";
    };

    dns = lib.mkOption {
      type = lib.types.str;
      default = "";
      example = "tail.example.org";
      description = "MagicDNS base domain.";
    };

    address = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      description = "Address Headscale listens on.";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 8080;
      description = "Port Headscale listens on.";
    };

    oidc = {
      issuer = lib.mkOption {
        type = lib.types.str;
        default = "";
        example = "id.example.org";
        description = "OIDC issuer URL or hostname. Empty disables OIDC login.";
      };

      clientId = lib.mkOption {
        type = lib.types.str;
        default = "headscale";
        description = "OIDC client ID used by Headscale.";
      };

      clientSecretPath = lib.mkOption {
        type = lib.types.str;
        default = "/secrets/headscale-oidc-client-secret";
        description = "File containing the Headscale OIDC client secret.";
      };

      allowedUsers = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "OIDC users allowed to log in. Empty leaves Headscale's default behavior.";
      };
    };

    extraSettings = lib.mkOption {
      type = lib.types.attrsOf lib.types.anything;
      default = { };
      description = "Extra Headscale settings merged over the module defaults.";
    };

    url = lib.mkOption {
      type = lib.types.str;
      readOnly = true;
      default = "https://${cfg.server}";
      description = "Derived public Headscale URL.";
    };
  };

  config = lib.mkIf (cfg.server != "") {
    assertions = [
      {
        assertion = cfg.dns != "";
        message = "services.my.headscale.dns must be set when services.my.headscale.server is set.";
      }
    ];

    services.headscale = {
      enable = true;
      address = cfg.address;
      port = cfg.port;

      settings = {
        server_url = cfg.url;
        dns = {
          base_domain = cfg.dns;
          magic_dns = true;
        };
        log.level = "info";
      }
      // lib.optionalAttrs (oidcIssuer != "") {
        oidc = {
          issuer = oidcIssuer;
          client_id = cfg.oidc.clientId;
          client_secret_path = cfg.oidc.clientSecretPath;
        }
        // lib.optionalAttrs (cfg.oidc.allowedUsers != [ ]) {
          allowed_users = cfg.oidc.allowedUsers;
        };
      }
      // cfg.extraSettings;
    };

    services.my.nginx.virtualHosts.${cfg.server}.locations."/" = {
      proxyPass = "http://${config.services.headscale.address}:${toString config.services.headscale.port}";
      proxyWebsockets = true;
      extraConfig = ''
        proxy_buffering off;
        proxy_read_timeout 3600s;
      '';
    };

  };
}
