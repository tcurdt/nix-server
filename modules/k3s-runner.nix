{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.my.k3s-runner;

  baseFlags = [
    "--disable=traefik"
    "--write-kubeconfig-mode=00640"
    "--write-kubeconfig-group=wheel"
  ];
in
{
  options.services.my.k3s-runner = {
    enable = lib.mkEnableOption "k3s runner";

    # openssl rand -hex 32
    tokenFile = lib.mkOption {
      type = lib.types.path;
      default = "/secrets/k3s_token";
      description = "File containing the k3s cluster token.";
    };

    waitForToken = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to wait for tokenFile to appear before starting k3s.";
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
    ];
    networking.firewall.allowedUDPPorts = [
      8472 # flannel: required if using multi-node for inter-node networking
    ];

    services.k3s = {
      enable = true;
      role = "agent";
      tokenFile = cfg.tokenFile;
      serverAddr = cfg.serverAddr;
      extraFlags = lib.concatStringsSep " " (baseFlags ++ cfg.extraFlags);
    };

    systemd.services.k3s = {
      unitConfig.ConditionPathExists = lib.mkIf cfg.waitForToken cfg.tokenFile;
    };

    systemd.paths.k3s-token = lib.mkIf cfg.waitForToken {
      description = "Start k3s when its token file appears";
      wantedBy = [ "multi-user.target" ];

      pathConfig = {
        PathExists = cfg.tokenFile;
        PathChanged = cfg.tokenFile;
        Unit = "k3s.service";
      };
    };

    systemd.tmpfiles.rules = lib.mkIf cfg.waitForToken [
      "d ${builtins.dirOf cfg.tokenFile} 0700 root root -"
    ];

    environment.systemPackages = [
      pkgs.k3s
    ];
  };
}
