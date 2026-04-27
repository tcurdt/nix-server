{
  pkgs,
  ...
}:
{
  imports = [
    # inputs.sops.nixosModules.sops
    ./k3s-cleanup.nix
  ];

  networking.firewall.allowedTCPPorts = [
    6443 # required so that pods can reach the API server
    # 2379 # etcd clients: required if using a "High Availability Embedded etcd"
    # 2380 # etcd peers: required if using a "High Availability Embedded etcd"
  ];
  networking.firewall.allowedUDPPorts = [
    8472 # flannel: required if using multi-node for inter-node networking
  ];

  services.k3s = {
    enable = true;
    role = "agent";
    tokenFile = "/secrets/k3s_token";
    serverAddr = "https://172.16.0.2:6443";
    extraFlags = toString [
      "--disable=traefik"
      # "--disable=metrics-server"
      # "--disable=servicelb"
      # "--disable-cloud-controller"
      # "--disable-kube-proxy"
      # "--disable-network-policy"
      # "--disable-helm-controller"
      "--write-kubeconfig-mode 00640"
      "--write-kubeconfig-group wheel"
    ];
  };

  # networking.nameservers = [ "10.43.0.10" ];

  environment.systemPackages = [
    pkgs.k3s
  ];

}
