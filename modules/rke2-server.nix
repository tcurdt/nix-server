{ pkgs, ... }:
{
  imports = [
    # inputs.sops.nixosModules.sops
    ./rke2-cleanup.nix
  ];

  # networking.firewall.allowedTCPPorts = [
  #   6443 # Kubernetes API server
  #   9345 # RKE2 supervisor API
  #   # 2379 # etcd clients: required for multi-server clusters
  #   # 2380 # etcd peers: required for multi-server clusters
  # ];
  # networking.firewall.allowedUDPPorts = [
  #   8472 # canal/flannel VXLAN for inter-node networking
  # ];

  networking.firewall.interfaces."PRIVATE_IFACE" = {
    allowedTCPPorts = [
      6443 # Kubernetes API
      9345 # RKE2 supervisor, server only
    ];
    allowedUDPPorts = [
      8472 # Canal/Flannel VXLAN
    ];
  };

  services.rke2 = {
    enable = true;
    role = "server";
    tokenFile = "/secrets/rke2_token";
    disable = [
      "rke2-ingress-nginx"
    ];
  };

  environment.shellAliases = {
    k = "kubectl";
    kall = "kubectl get all -A";
  };

  environment.variables = {
    KUBECONFIG = "/etc/rancher/rke2/rke2.yaml";
  };

  environment.systemPackages = [
    pkgs.rke2
    pkgs.k9s
    pkgs.stern
  ];

}
