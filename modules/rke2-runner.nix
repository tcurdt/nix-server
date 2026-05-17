{ pkgs, ... }:
{
  imports = [
    # inputs.sops.nixosModules.sops
    ./rke2-cleanup.nix
  ];

  networking.firewall.allowedTCPPorts = [
    6443 # Kubernetes API server
    9345 # RKE2 supervisor API
  ];
  networking.firewall.allowedUDPPorts = [
    8472 # canal/flannel VXLAN for inter-node networking
  ];

  services.rke2 = {
    enable = true;
    role = "agent";
    tokenFile = "/secrets/rke2_token";
    serverAddr = "https://172.16.0.2:9345";
  };

  environment.systemPackages = [
    pkgs.rke2
  ];

}
