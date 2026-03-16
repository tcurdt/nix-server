{
  pkgs,
  lib,
  config,
  ...
}:

let
  cfg = config.services.angie;

  autheliaPort =
    name:
    let
      instances = config.services.authelia.instances;
      addr = lib.attrByPath [ name "settings" "server" "address" ] "tcp://:9091/" instances;
      # addr is like "tcp://:9091/" — extract the port number
      port = lib.last (
        lib.splitString ":" (lib.head (lib.splitString "/" (lib.removePrefix "tcp://:" addr)))
      );
    in
    port;

  # Generate the internal Authelia authz location for a vhost
  mkAutheliaLocation = port: {
    extraConfig = ''
      internal;
      proxy_pass http://127.0.0.1:${port}/api/authz/auth-request;
      proxy_set_header X-Original-Method $request_method;
      proxy_set_header X-Original-URL $scheme://$http_host$request_uri;
      proxy_set_header X-Forwarded-For $remote_addr;
      proxy_set_header Content-Length "";
      proxy_pass_request_body off;
    '';
  };

  # Inject auth_request into a location's extraConfig
  mkProtectedExtraConfig = userExtraConfig: ''
    auth_request /internal/authelia/authz;
    auth_request_set $redirection_url $upstream_http_location;
    error_page 401 =302 $redirection_url;
    ${userExtraConfig}
  '';

  # Convert a single angie location to a nginx location attrset
  mkNginxLocation =
    protect: _path: loc:
    let
      returnLine = lib.optionalString (loc.return != null) "return ${loc.return};";
      proxyBlock = lib.optionalString (loc.proxyPass != null) ''
        proxy_pass ${loc.proxyPass};
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        ${lib.optionalString loc.proxyWebsockets ''
          proxy_http_version 1.1;
          proxy_set_header Upgrade $http_upgrade;
          proxy_set_header Connection "upgrade";
        ''}
      '';
      baseExtra = lib.concatStringsSep "\n" (
        lib.filter (s: s != "") [
          returnLine
          proxyBlock
          loc.extraConfig
        ]
      );
    in
    {
      extraConfig = if protect then mkProtectedExtraConfig baseExtra else baseExtra;
    };

  # Convert a single angie vhost to a nginx virtualHost attrset
  mkNginxVhost =
    name: vhost:
    let
      protect = vhost.authrequest != null;
      port = lib.optionalString protect (autheliaPort vhost.authrequest);

      userLocations = lib.mapAttrs (mkNginxLocation protect) vhost.locations;
      autheliaLocation = lib.optionalAttrs protect {
        "/internal/authelia/authz" = mkAutheliaLocation port;
      };
      allLocations = autheliaLocation // userLocations;
    in
    {
      forceSSL = vhost.forceSSL;
      sslCertificate = lib.mkIf vhost.selfSigned "/var/lib/nginx/${name}.crt";
      sslCertificateKey = lib.mkIf vhost.selfSigned "/var/lib/nginx/${name}.key";
      locations = allLocations;
    };

in
{
  # --------------------------------------------------------------------------
  # Options
  # --------------------------------------------------------------------------
  options.services.angie = {

    virtualHosts = lib.mkOption {
      default = { };
      description = "Virtual host configurations.";
      type = lib.types.attrsOf (
        lib.types.submodule {
          options = {

            forceSSL = lib.mkOption {
              type = lib.types.bool;
              default = false;
            };

            selfSigned = lib.mkOption {
              type = lib.types.bool;
              default = false;
              description = "Generate and use a self-signed certificate for this vhost.";
            };

            authrequest = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = ''
                Name of the Authelia instance to use for forward auth.
                When set, all locations on this vhost require authentication.
              '';
            };

            locations = lib.mkOption {
              default = { };
              description = "Location configurations.";
              type = lib.types.attrsOf (
                lib.types.submodule {
                  options = {
                    return = lib.mkOption {
                      type = lib.types.nullOr lib.types.str;
                      default = null;
                      description = "Nginx return directive argument (e.g. '200 \"hello\\n\"').";
                    };
                    proxyPass = lib.mkOption {
                      type = lib.types.nullOr lib.types.str;
                      default = null;
                      description = "Upstream URL to proxy to.";
                    };
                    proxyWebsockets = lib.mkOption {
                      type = lib.types.bool;
                      default = false;
                    };
                    extraConfig = lib.mkOption {
                      type = lib.types.lines;
                      default = "";
                      description = "Raw nginx config appended to this location block.";
                    };
                  };
                }
              );
            };

          };
        }
      );
    };
  };

  # --------------------------------------------------------------------------
  # Config
  # --------------------------------------------------------------------------
  config = lib.mkIf (cfg.virtualHosts != { }) {

    services.nginx = {
      enable = true;
      package = pkgs.angie;

      virtualHosts = lib.mapAttrs mkNginxVhost cfg.virtualHosts;
    };

    services.nginx-selfsigned.domains = lib.mapAttrsToList (name: _: name) (
      lib.filterAttrs (_: v: v.selfSigned) cfg.virtualHosts
    );

    systemd.tmpfiles.rules = [
      "d /var/lib/nginx 0750 nginx nginx -"
      "d /var/lib/nginx/acme 0700 nginx nginx -"
    ];

    systemd.services.nginx.serviceConfig.ReadWritePaths = [ "/var/lib/nginx" ];
  };
}
