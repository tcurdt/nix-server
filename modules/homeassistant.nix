{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.my.homeassistant;
  proxyAddress = builtins.head cfg.serverHost;
  proxyUrl = "http://${proxyAddress}:${toString cfg.serverPort}";
in
{
  imports = [
    ./nginx.nix
  ];

  options.services.my.homeassistant = {
    enable = lib.mkEnableOption "Home Assistant";

    server = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "home.example.org";
      description = "Public server name for Home Assistant. Null disables nginx registration.";
    };

    name = lib.mkOption {
      type = lib.types.str;
      default = "Home";
      description = "Home Assistant location name.";
    };

    timeZone = lib.mkOption {
      type = lib.types.str;
      default = "UTC";
      example = "Europe/Berlin";
      description = "Home Assistant time zone.";
    };

    serverHost = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "127.0.0.1" ];
      description = "Addresses Home Assistant listens on.";
    };

    serverPort = lib.mkOption {
      type = lib.types.port;
      default = 8123;
      description = "Port Home Assistant listens on.";
    };

    config = lib.mkOption {
      type = lib.types.attrsOf lib.types.anything;
      default = { };
      description = "Extra Home Assistant config merged over the module defaults.";
    };

    extraPackages = lib.mkOption {
      type = lib.types.functionTo (lib.types.listOf lib.types.package);
      default = _: [ ];
      description = "Extra Python packages for Home Assistant.";
    };

    url = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      readOnly = true;
      default = if cfg.server == null then null else "https://${cfg.server}";
      description = "Derived public Home Assistant URL.";
    };
  };

  config = lib.mkIf cfg.enable {
    services.home-assistant = {
      enable = true;
      extraPackages = cfg.extraPackages;
      config = lib.recursiveUpdate {
        http = {
          server_host = cfg.serverHost;
          server_port = cfg.serverPort;
        }
        // lib.optionalAttrs (cfg.server != null) {
          use_x_forwarded_for = true;
          trusted_proxies = [ "127.0.0.1" ];
        };
        homeassistant = {
          inherit (cfg) name;
          time_zone = cfg.timeZone;
          temperature_unit = "C";
          unit_system = "metric";
        };
      } cfg.config;
    };

    environment.systemPackages = [
      pkgs.home-assistant-cli
    ];

    services.my.nginx = lib.mkIf (cfg.server != null) {
      enable = true;
      virtualHosts.${cfg.server}.locations."/" = {
        proxyPass = proxyUrl;
        proxyWebsockets = true;
      };
    };
  };
}
