{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.my.k3s-server;

  baseFlags = [
    "--disable=traefik"
    "--write-kubeconfig-mode=00640"
    "--write-kubeconfig-group=wheel"
  ];

  floatingIp = cfg.floating-ip;
  floatingIpStartCommands =
    lib.optionals (floatingIp.ipv4 != null) [
      "${pkgs.iproute2}/bin/ip addr replace ${floatingIp.ipv4} dev ${floatingIp.interface}"
    ]
    ++ lib.optionals (floatingIp.ipv4Gateway != null) [
      "${pkgs.iproute2}/bin/ip route replace default via ${floatingIp.ipv4Gateway} dev ${floatingIp.interface}"
    ]
    ++ lib.optionals (floatingIp.ipv6 != null) [
      "${pkgs.iproute2}/bin/ip -6 addr replace ${floatingIp.ipv6} dev ${floatingIp.interface}"
    ]
    ++ lib.optionals (floatingIp.ipv6Gateway != null) [
      "${pkgs.iproute2}/bin/ip -6 route replace default via ${floatingIp.ipv6Gateway} dev ${floatingIp.interface}"
    ];

  floatingIpStopCommands =
    lib.optionals (floatingIp.ipv4 != null) [
      "-${pkgs.iproute2}/bin/ip addr del ${floatingIp.ipv4} dev ${floatingIp.interface}"
    ]
    ++ lib.optionals (floatingIp.ipv4Gateway != null) [
      "-${pkgs.iproute2}/bin/ip route del default via ${floatingIp.ipv4Gateway} dev ${floatingIp.interface}"
    ]
    ++ lib.optionals (floatingIp.ipv6 != null) [
      "-${pkgs.iproute2}/bin/ip -6 addr del ${floatingIp.ipv6} dev ${floatingIp.interface}"
    ]
    ++ lib.optionals (floatingIp.ipv6Gateway != null) [
      "-${pkgs.iproute2}/bin/ip -6 route del default via ${floatingIp.ipv6Gateway} dev ${floatingIp.interface}"
    ];
in
{
  options.services.my.k3s-server = {
    enable = lib.mkEnableOption "k3s server";

    # openssl rand -hex 32
    tokenFile = lib.mkOption {
      type = lib.types.path;
      default = "/secrets/k3s_token";
      description = "File containing the k3s cluster token.";
    };

    clusterInit = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Whether this server should initialize an embedded etcd cluster.";
    };

    extraFlags = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Additional flags passed to k3s server.";
    };

    floating-ip = {
      enable = lib.mkEnableOption "k3s floating IP hooks";

      ipv4 = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Optional IPv4 address with subnet mask to add when k3s starts.";
      };

      ipv4Gateway = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Optional IPv4 gateway address for the default route.";
      };

      ipv6 = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Optional IPv6 address with subnet mask to add when k3s starts.";
      };

      ipv6Gateway = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Optional IPv6 gateway address for the default route.";
      };

      interface = lib.mkOption {
        type = lib.types.str;
        default = "eth0";
        description = "Network interface to which floating addresses are assigned.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    networking.firewall.allowedTCPPorts = [
      6443 # required so that pods can reach the API server
    ];
    networking.firewall.allowedUDPPorts = [
      8472 # flannel: required if using multi-node for inter-node networking
    ];

    services.k3s = {
      enable = true;
      role = "server";
      tokenFile = cfg.tokenFile;
      clusterInit = cfg.clusterInit;
      extraFlags = lib.concatStringsSep " " (baseFlags ++ cfg.extraFlags);
    };

    systemd.services.k3s.serviceConfig = lib.mkIf floatingIp.enable {
      ExecStartPost = floatingIpStartCommands;
      ExecStop = floatingIpStopCommands;
    };

    environment.shellAliases = {
      k = "kubectl";
      kall = "kubectl get all -A";
    };

    environment.variables = {
      KUBECONFIG = "/etc/rancher/k3s/k3s.yaml";
    };

    environment.systemPackages = [
      pkgs.k3s
      pkgs.k9s
      pkgs.stern
    ];
  };
}
