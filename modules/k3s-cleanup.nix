{
  # config,
  # lib,
  pkgs,
  ...
}:

let

  k3s-reset = pkgs.writeScriptBin "k3s-reset" ''
    #!${pkgs.bash}/bin/bash
    systemctl stop k3s
    rm -rf /var/lib/rancher/k3s/
    rm -rf /etc/rancher/k3s/
  '';

  k3s-image-prune = pkgs.writeScriptBin "k3s-image-prune" ''
    #!${pkgs.bash}/bin/bash
    echo "$(date): k3s image prune start"
    ${pkgs.k3s}/bin/k3s crictl --timeout 60s rmi --prune
    echo "$(date): k3s image prune stop"
  '';

in
{

  users.users.root = {
    packages = [
      k3s-reset
      k3s-image-prune
    ];
  };

  systemd.services.k3s-image-prune = {
    description = "clean up unused k3s container images";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${k3s-image-prune}/bin/k3s-image-prune";
      User = "root";
      After = [ "k3s.service" ];
      Requires = [ "k3s.service" ];
    };
  };

  systemd.timers.k3s-image-prune = {
    description = "timer for k3s image prune";
    wantedBy = [ "timers.target" ];
    partOf = [ "k3s-image-prune.service" ];
    timerConfig = {
      OnCalendar = "*-*-* 03:00:00"; # daily at 3am
      Persistent = true;
    };
  };

}
