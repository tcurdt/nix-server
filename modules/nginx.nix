{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.my.nginx;
in
{
  options.services.my.nginx = {
    enable = lib.mkEnableOption "nginx web edge";

    acme = {
      email = lib.mkOption {
        type = lib.types.str;
        default = "tcurdt@vafer.org";
        description = "Email address used for ACME registration.";
      };
    };

    forceSSL = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether service modules should force SSL for registered nginx virtual hosts.";
    };

    enableACME = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether service modules should enable ACME for registered nginx virtual hosts.";
    };

    virtualHosts = lib.mkOption {
      default = { };
      description = "Public nginx virtual host definitions registered by service modules.";
      type = lib.types.attrsOf (
        lib.types.submodule {
          freeformType = lib.types.attrsOf lib.types.anything;
        }
      );
    };
  };

  config = lib.mkIf cfg.enable {
    services.nginx = {
      enable = true;
      package = lib.mkDefault pkgs.angie;

      virtualHosts = lib.mapAttrs (
        _: vhost:
        vhost
        // {
          forceSSL = cfg.forceSSL;
          enableACME = cfg.enableACME;
        }
      ) cfg.virtualHosts;
    };

    security.acme.acceptTerms = true;
    security.acme.defaults.email = cfg.acme.email;

    networking.firewall.allowedTCPPorts = [
      80
      443
    ];
  };
}
