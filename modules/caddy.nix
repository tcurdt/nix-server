{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.my.caddy;
in
{
  options.services.my.caddy = {
    enable = lib.mkEnableOption "Caddy web edge";

    package = lib.mkPackageOption pkgs "caddy" { };

    acme = {
      email = lib.mkOption {
        type = lib.types.str;
        default = "tcurdt@vafer.org";
        description = "Email address used for ACME registration.";
      };
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Whether to open HTTP and HTTPS ports on all interfaces, including UDP
        for HTTP/3. Disable for VPN-only access and allow traffic on the VPN
        interface separately. This does not restrict Caddy's listen addresses.
      '';
    };

    environmentFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "/run/secrets/caddy.env";
      description = ''
        Runtime environment file containing secrets such as DNS API tokens.
        Keep its contents out of the Nix store. DNS-01 also requires a Caddy
        package with the appropriate DNS provider plugin and DNS configuration.
      '';
    };

    globalConfig = lib.mkOption {
      type = lib.types.lines;
      default = "";
      description = "Additional Caddy global options, for example an ACME DNS provider.";
    };

    virtualHosts = lib.mkOption {
      default = { };
      description = ''
        Caddy virtual host definitions registered by service modules.
        Caddy manages HTTPS certificates and HTTP redirects automatically.
      '';
      type = lib.types.attrsOf (
        lib.types.submodule {
          freeformType = lib.types.attrsOf lib.types.anything;
        }
      );
    };
  };

  config = lib.mkIf cfg.enable {
    services.caddy = {
      enable = true;
      package = lib.mkDefault cfg.package;
      email = cfg.acme.email;
      inherit (cfg)
        openFirewall
        environmentFile
        globalConfig
        virtualHosts
        ;
    };
  };
}
