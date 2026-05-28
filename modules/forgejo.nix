{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.my.forgejo;
  oidcIssuer = if cfg.oidc.issuer == "" then "" else "https://${cfg.oidc.issuer}";
in
{
  options.services.my.forgejo = {
    server = lib.mkOption {
      type = lib.types.str;
      default = "";
      example = "git.example.org";
      description = "Public Forgejo server name. Empty disables the service.";
    };

    address = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      description = "Address Forgejo listens on.";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 3000;
      description = "Port Forgejo listens on.";
    };

    lfs = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to enable Forgejo LFS support.";
    };

    disableRegistration = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to disable self-service Forgejo registration.";
    };

    oidc = {
      issuer = lib.mkOption {
        type = lib.types.str;
        default = "";
        example = "id.example.org";
        description = "OIDC issuer URL or hostname. Empty disables OIDC bootstrap.";
      };

      name = lib.mkOption {
        type = lib.types.str;
        default = "pocket-id";
        description = "Forgejo authentication source name.";
      };

      clientId = lib.mkOption {
        type = lib.types.str;
        default = "forgejo";
        description = "OIDC client ID used by Forgejo.";
      };

      clientSecretPath = lib.mkOption {
        type = lib.types.str;
        default = "/secrets/forgejo-oidc-client-secret";
        description = "File containing the Forgejo OIDC client secret.";
      };
    };

    extraSettings = lib.mkOption {
      type = lib.types.attrsOf lib.types.anything;
      default = { };
      description = "Extra Forgejo settings merged over the module defaults.";
    };

    url = lib.mkOption {
      type = lib.types.str;
      readOnly = true;
      default = "https://${cfg.server}/";
      description = "Derived public Forgejo root URL.";
    };
  };

  config = lib.mkIf (cfg.server != "") {
    services.forgejo = {
      enable = true;
      lfs.enable = cfg.lfs;

      settings = {
        server = {
          DOMAIN = cfg.server;
          ROOT_URL = cfg.url;
          HTTP_ADDR = cfg.address;
          HTTP_PORT = cfg.port;
        };

        service.DISABLE_REGISTRATION = cfg.disableRegistration;
        session.COOKIE_SECURE = true;
      }
      // cfg.extraSettings;
    };

    services.my.nginx.virtualHosts.${cfg.server}.locations."/" = {
      proxyPass = "http://${config.services.forgejo.settings.server.HTTP_ADDR}:${toString config.services.forgejo.settings.server.HTTP_PORT}";
      proxyWebsockets = true;
      extraConfig = ''
        client_max_body_size 512M;
      '';
    };

    systemd.services.forgejo-bootstrap-oidc = lib.mkIf (oidcIssuer != "") {
      wantedBy = [ "multi-user.target" ];
      after = [ "forgejo.service" ];
      requires = [ "forgejo.service" ];
      path = [
        config.services.forgejo.package
        pkgs.gnugrep
      ];
      serviceConfig = {
        Type = "oneshot";
        User = "forgejo";
        Group = "forgejo";
      };
      script = ''
        forgejo admin auth list --config /var/lib/forgejo/custom/conf/app.ini | grep -q ${lib.escapeShellArg cfg.oidc.name} || \
          forgejo admin auth add-oauth \
            --config /var/lib/forgejo/custom/conf/app.ini \
            --name ${lib.escapeShellArg cfg.oidc.name} \
            --provider openidConnect \
            --key ${lib.escapeShellArg cfg.oidc.clientId} \
            --secret "$(${pkgs.coreutils}/bin/cat ${lib.escapeShellArg cfg.oidc.clientSecretPath})" \
            --auto-discover-url ${lib.escapeShellArg "${oidcIssuer}/.well-known/openid-configuration"}
      '';
    };
  };
}
