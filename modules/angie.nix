{
  pkgs,
  lib,
  config,
  ...
}:

let
  cfg = config.services.angie;

  # All vhosts that need OIDC
  oidcVhosts = lib.filterAttrs (_: v: v.oidc != null) cfg.virtualHosts;
  needsLua = oidcVhosts != { };

  # Lua resty packages and path
  luaPackages = pkgs.luajitPackages;
  luaResty = with luaPackages; [
    lua-resty-openidc
    lua-resty-http
    lua-resty-jwt
    lua-resty-session
    lua-resty-openssl
    lua-resty-core
    lua-resty-lrucache
  ];
  luaPath = lib.concatStringsSep ";" (map (p: "${p}/share/lua/5.1/?.lua") luaResty);

  # Build a shared Lua opts file for a vhost with OIDC configured
  mkOidcOptsFile =
    name: vhost:
    let
      oidc = vhost.oidc;
      provider = cfg.oidcProviders.${oidc.provider};
    in
    pkgs.writeText "${name}-oidc-opts.lua" ''
      return {
        redirect_uri              = "https://${name}/auth/callback",
        discovery                 = "${provider.discoveryUrl}",
        client_id                 = "${oidc.clientId}",
        client_secret_file        = "${oidc.secretFile}",
        logout_path               = "/auth/logout",
        redirect_after_logout_uri = "/auth/logged-out",
        revoke_tokens_on_logout   = true,
      }
    '';

  # Generate the access_by_lua_block for a protected location
  mkAccessBlock = optsFile: ''
    access_by_lua_block {
      local openidc = require("resty.openidc")
      local opts = dofile("${optsFile}")
      local res, err = openidc.authenticate(opts)
      if err then
        ngx.status = 500
        ngx.say(err)
        ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
      end
    }
  '';

  # Generate the auto locations for OIDC callback/logout
  mkOidcLocations = optsFile: {
    "/auth/callback" = {
      extraConfig = ''
        access_by_lua_block {
          local openidc = require("resty.openidc")
          local opts = dofile("${optsFile}")
          local res, err = openidc.authenticate(opts)
          if err then
            ngx.status = 500
            ngx.say(err)
            ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
          end
        }
      '';
    };
    "/auth/logout" = {
      extraConfig = ''
        access_by_lua_block {
          local openidc = require("resty.openidc")
          local opts = dofile("${optsFile}")
          openidc.logout(opts)
        }
      '';
    };
    "/auth/logged-out" = {
      extraConfig = ''
        default_type text/plain;
        return 200 "logged out\n";
      '';
    };
  };

  # Convert a single angie location to a nginx location attrset
  mkNginxLocation =
    optsFile: _path: loc:
    let
      accessBlock = lib.optionalString (loc.protect && optsFile != null) (mkAccessBlock optsFile);
      returnLine = lib.optionalString (loc.return != null) "return ${loc.return};";
      proxyBlock = lib.optionalString (loc.proxyPass != null) ''
        proxy_pass ${loc.proxyPass};
        ${lib.optionalString loc.proxyWebsockets ''
          proxy_http_version 1.1;
          proxy_set_header Upgrade $http_upgrade;
          proxy_set_header Connection "upgrade";
        ''}
      '';
    in
    {
      extraConfig = lib.concatStringsSep "\n" (
        lib.filter (s: s != "") [
          accessBlock
          returnLine
          proxyBlock
          loc.extraConfig
        ]
      );
    };

  # Convert a single angie vhost to a nginx virtualHost attrset
  mkNginxVhost =
    name: vhost:
    let
      optsFile = if vhost.oidc != null then mkOidcOptsFile name vhost else null;
      userLocations = lib.mapAttrs (mkNginxLocation optsFile) vhost.locations;
      oidcLocations = lib.optionalAttrs (vhost.oidc != null) (mkOidcLocations optsFile);
      allLocations = oidcLocations // userLocations;
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

    oidcProviders = lib.mkOption {
      default = { };
      description = "Named OIDC provider configurations.";
      type = lib.types.attrsOf (
        lib.types.submodule {
          options.discoveryUrl = lib.mkOption {
            type = lib.types.str;
            description = "OIDC discovery endpoint URL.";
          };
        }
      );
    };

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

            oidc = lib.mkOption {
              default = null;
              description = "OIDC configuration. When set, Lua auth locations are generated automatically.";
              type = lib.types.nullOr (
                lib.types.submodule {
                  options = {
                    provider = lib.mkOption {
                      type = lib.types.str;
                      description = "Key of the provider in services.angie.oidcProviders.";
                    };
                    clientId = lib.mkOption {
                      type = lib.types.str;
                      description = "OIDC client ID.";
                    };
                    secretFile = lib.mkOption {
                      type = lib.types.str;
                      description = "Path to a file containing the OIDC client secret.";
                    };
                  };
                }
              );
            };

            locations = lib.mkOption {
              default = { };
              description = "Location configurations.";
              type = lib.types.attrsOf (
                lib.types.submodule {
                  options = {
                    protect = lib.mkOption {
                      type = lib.types.bool;
                      default = false;
                      description = "Require OIDC authentication for this location.";
                    };
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

    nixpkgs.overlays = lib.mkIf needsLua [
      (final: prev: {
        angieWithLua = prev.angie.override {
          withAcme = true;
          modules = [ prev.nginxModules.lua ];
        };
      })
    ];

    services.nginx = {
      enable = true;
      package = if needsLua then pkgs.angieWithLua else pkgs.angie;

      commonHttpConfig = lib.mkIf needsLua ''
        lua_package_path '${luaPath};;';
      '';

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
