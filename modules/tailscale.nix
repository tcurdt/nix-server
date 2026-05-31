{
  config,
  lib,
  ...
}:

let
  cfg = config.services.my.tailscale;
  serverUrl = if cfg.server == null then null else "https://${cfg.server}";
in
{
  options.services.my.tailscale = {
    enable = lib.mkEnableOption "tailscale";

    authKeyFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = "/secrets/tailscale.key";
      description = "File containing the Tailscale auth key. Null disables automatic login.";
    };

    server = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "head.example.org";
      description = "Headscale server URL or hostname. Null uses the default Tailscale control plane.";
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Whether the upstream Tailscale module should open firewall ports.";
    };

    trustedInterface = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = "tailscale0";
      description = "Tailscale interface to trust in the firewall. Null disables this.";
    };

    extraUpFlags = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Extra flags passed to tailscale up.";
    };
  };

  config = lib.mkIf cfg.enable {
    services.tailscale = {
      enable = true;
      openFirewall = cfg.openFirewall;
      authKeyFile = lib.mkIf (cfg.authKeyFile != null) cfg.authKeyFile;
      extraUpFlags =
        lib.optionals (serverUrl != null) [
          "--login-server=${serverUrl}"
        ]
        ++ cfg.extraUpFlags;
    };

    networking.firewall.trustedInterfaces = lib.mkIf (cfg.trustedInterface != null) [
      cfg.trustedInterface
    ];
  };
}
