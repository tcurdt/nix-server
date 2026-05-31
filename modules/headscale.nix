{
  config,
  lib,
  ...
}:

let
  cfg = config.services.my.headscale;
  oidcIssuer =
    if cfg.oidc.issuer == "" then
      ""
    else if lib.hasPrefix "http://" cfg.oidc.issuer || lib.hasPrefix "https://" cfg.oidc.issuer then
      cfg.oidc.issuer
    else
      "https://${cfg.oidc.issuer}";
in
{
  options.services.my.headscale = {
    server = lib.mkOption {
      type = lib.types.str;
      default = "";
      example = "head.example.org";
      description = "Public Headscale server name. Empty disables the service.";
    };

    domain = lib.mkOption {
      type = lib.types.str;
      default = "";
      example = "tail.example.org";
      description = "MagicDNS base domain.";
    };

    nameservers = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [ "1.1.1.1" ];
      description = "Global DNS nameservers passed to Tailscale clients. Empty disables overriding local DNS.";
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

      # sudo sh -c 'openssl rand -hex 32 | tr -d "\n" > /secrets/headscale-oidc-client-secret'
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
        assertion = cfg.domain != "";
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
          base_domain = cfg.domain;
          magic_dns = true;
          override_local_dns = cfg.nameservers != [ ];
          nameservers.global = cfg.nameservers;
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
