{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.my.k3s-runner;
  dynamicConfigFile = "/run/k3s-agent-dynamic.yaml";

  baseFlags = [ ];
in
{
  options.services.my.k3s-runner = {
    enable = lib.mkEnableOption "k3s runner";

    # openssl rand -hex 32
    tokenFile = lib.mkOption {
      type = lib.types.path;
      default = "/secrets/cluster-token";
      description = "File containing the k3s cluster token.";
    };

    serverAddr = lib.mkOption {
      type = lib.types.str;
      default = "https://172.16.0.2:6443";
      description = "k3s server API URL this agent joins.";
    };

    extraFlags = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Additional flags passed to k3s agent.";
    };
  };

  config = lib.mkIf cfg.enable {
    networking.firewall.allowedTCPPorts = [
      6443 # required so that pods can reach the API server
      10250 # kubelet metrics endpoint for metrics-server
    ];
    networking.firewall.allowedUDPPorts = [
      8472 # flannel: required if using multi-node for inter-node networking
    ];

    services.k3s = {
      enable = true;
      role = "agent";
      tokenFile = cfg.tokenFile;
      serverAddr = cfg.serverAddr;
      extraFlags = lib.concatStringsSep " " (
        [ "--config=${dynamicConfigFile}" ] ++ baseFlags ++ cfg.extraFlags
      );
    };

    systemd.services.k3s = {
      unitConfig.ConditionPathExists = cfg.tokenFile;
      preStart = ''
        node_info="$(${pkgs.iproute2}/bin/ip -4 -o addr show scope global | ${pkgs.gawk}/bin/awk '{ split($4, a, "/"); if (a[1] ~ /^172[.]16[.]0[.]/) { print $2, a[1]; exit } }')"
        node_interface="''${node_info%% *}"
        node_ip="''${node_info##* }"

        if [ -z "$node_info" ]; then
          echo "could not find private 172.16.0.x node IP and interface" >&2
          exit 1
        fi

        printf 'node-ip: "%s"\nflannel-iface: "%s"\n' "$node_ip" "$node_interface" > ${dynamicConfigFile}
      '';
    };

    environment.systemPackages = [
      pkgs.k3s
    ];
  };
}
