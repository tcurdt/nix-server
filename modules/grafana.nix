{
  config,
  lib,
  ...
}:

let
  cfg = config.services.my.grafana;
  listen = "${cfg.address}:${toString cfg.port}";
  oidcIssuer =
    if cfg.oidc.issuer == "" then
      ""
    else if lib.hasPrefix "http://" cfg.oidc.issuer || lib.hasPrefix "https://" cfg.oidc.issuer then
      cfg.oidc.issuer
    else
      "https://${cfg.oidc.issuer}";
in
{
  imports = [
    ./nginx.nix
  ];

  options.services.my.grafana = {
    enable = lib.mkEnableOption "grafana";

    server = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "grafana.example.org";
      description = "Public server name for Grafana. Null disables nginx registration.";
    };

    address = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      description = "Address Grafana listens on.";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 3001;
      description = "Port Grafana listens on.";
    };

    secretKeyPath = lib.mkOption {
      type = lib.types.str;
      default = "/secrets/grafana-secret-key";
      description = "File containing Grafana's secret_key.";
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
        default = "grafana";
        description = "OIDC client ID used by Grafana.";
      };

      clientSecretPath = lib.mkOption {
        type = lib.types.str;
        default = "/secrets/grafana-oidc-client-secret";
        description = "File containing the Grafana OIDC client secret.";
      };

      scopes = lib.mkOption {
        type = lib.types.str;
        default = "openid profile email";
        description = "OIDC scopes requested by Grafana.";
      };

      allowSignUp = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Whether Grafana may create users from OIDC logins.";
      };

      settings = lib.mkOption {
        type = lib.types.attrsOf lib.types.anything;
        default = { };
        description = "Extra auth.generic_oauth settings merged over the OIDC defaults.";
      };
    };

    settings = lib.mkOption {
      type = lib.types.attrsOf lib.types.anything;
      default = { };
      description = "Extra Grafana settings merged over the module defaults.";
    };

    provision = lib.mkOption {
      type = lib.types.attrsOf lib.types.anything;
      default = { };
      description = "Grafana provisioning settings.";
    };

    url = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      readOnly = true;
      default = if cfg.server == null then null else "https://${cfg.server}/";
      description = "Derived public Grafana root URL.";
    };
  };

  config = lib.mkIf cfg.enable {
    services.grafana = {
      enable = true;
      settings =
        lib.recursiveUpdate
          {
            analytics.reporting_enabled = false;
            "auth.grafana_com".auto_login = true;
            server = {
              http_addr = cfg.address;
              http_port = cfg.port;
            }
            // lib.optionalAttrs (cfg.server != null) {
              domain = cfg.server;
              root_url = cfg.url;
            };
            security = {
              admin_user = "admin";
              admin_email = "admin@localhost";
              admin_password = "admin";
              secret_key = "$__file{${cfg.secretKeyPath}}";
            };
          }
          (
            lib.recursiveUpdate (lib.optionalAttrs (oidcIssuer != "") {
              "auth.generic_oauth" = {
                enabled = true;
                name = "Pocket ID";
                allow_sign_up = cfg.oidc.allowSignUp;
                client_id = cfg.oidc.clientId;
                client_secret = "$__file{${cfg.oidc.clientSecretPath}}";
                scopes = cfg.oidc.scopes;
                auth_url = "${oidcIssuer}/authorize";
                token_url = "${oidcIssuer}/api/oidc/token";
                api_url = "${oidcIssuer}/api/oidc/userinfo";
                use_pkce = true;
              }
              // cfg.oidc.settings;
            }) cfg.settings
          );
      provision = cfg.provision;
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
