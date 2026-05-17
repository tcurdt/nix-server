{ pkgs, ... }:
let
  rke2-reset = pkgs.writeScriptBin "rke2-reset" ''
    #! ${pkgs.bash}/bin/bash
    systemctl stop rke2-server rke2-agent
    rm -rf /var/lib/rancher/rke2/
    rm -rf /etc/rancher/rke2/
  '';

  rke2-image-prune = pkgs.writeScriptBin "rke2-image-prune" ''
    #! ${pkgs.bash}/bin/bash
    echo "$(date): rke2 image prune start"
    ${pkgs.rke2}/bin/rke2 crictl --timeout 60s rmi --prune
    echo "$(date): rke2 image prune stop"
  '';
in
{

  environment.systemPackages = [
    rke2-reset
    rke2-image-prune
  ];

}
