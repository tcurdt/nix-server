{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.services.k3s-floating-ip;
in
{
  options.services.k3s-floating-ip = {
    enable = mkEnableOption "k3s static IP configuration";

    ipv4 = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Optional static IPv4 address with subnet mask to add when k3s starts";
    };

    ipv4Gateway = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Optional IPv4 gateway address for the default route";
    };

    ipv6 = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Optional static IPv6 address with subnet mask to add when k3s starts";
    };

    ipv6Gateway = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Optional IPv6 gateway address for the default route";
    };

    interface = mkOption {
      type = types.str;
      default = "eth0";
      description = "Network interface to which the static IP will be assigned";
    };
  };

  config = mkIf cfg.enable {
    systemd.services.k3s = {
      serviceConfig = {
        ExecStartPost =
          let
            ipv4Cmd = optional (
              cfg.ipv4 != null
            ) "${pkgs.iproute2}/bin/ip addr replace ${cfg.ipv4} dev ${cfg.interface}";
            ipv4RouteCmd = optional (
              cfg.ipv4Gateway != null
            ) "${pkgs.iproute2}/bin/ip route replace default via ${cfg.ipv4Gateway} dev ${cfg.interface}";
            ipv6Cmd = optional (
              cfg.ipv6 != null
            ) "${pkgs.iproute2}/bin/ip -6 addr replace ${cfg.ipv6} dev ${cfg.interface}";
            ipv6RouteCmd = optional (
              cfg.ipv6Gateway != null
            ) "${pkgs.iproute2}/bin/ip -6 route replace default via ${cfg.ipv6Gateway} dev ${cfg.interface}";
          in
          ipv4Cmd ++ ipv4RouteCmd ++ ipv6Cmd ++ ipv6RouteCmd;

        ExecStop =
          let
            ipv4Cmd = optional (
              cfg.ipv4 != null
            ) "-${pkgs.iproute2}/bin/ip addr del ${cfg.ipv4} dev ${cfg.interface}";
            ipv4RouteCmd = optional (
              cfg.ipv4Gateway != null
            ) "-${pkgs.iproute2}/bin/ip route del default via ${cfg.ipv4Gateway} dev ${cfg.interface}";
            ipv6Cmd = optional (
              cfg.ipv6 != null
            ) "-${pkgs.iproute2}/bin/ip -6 addr del ${cfg.ipv6} dev ${cfg.interface}";
            ipv6RouteCmd = optional (
              cfg.ipv6Gateway != null
            ) "-${pkgs.iproute2}/bin/ip -6 route del default via ${cfg.ipv6Gateway} dev ${cfg.interface}";
          in
          ipv4Cmd ++ ipv4RouteCmd ++ ipv6Cmd ++ ipv6RouteCmd;
      };
    };
  };
}
