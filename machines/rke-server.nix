{
  # pkgs,
  # inputs,
  ...
}:
{

  networking.hostName = "rke-server";
  networking.domain = "nixos";
  system.stateVersion = "25.11";

  imports = [

    ../hardware/hetzner-efi.nix
    ../modules/server.nix
    ../modules/no-registry.nix
    ../modules/builders.nix
    ../modules/mmdb.nix

    ../users/root.nix
    ../users/ops.nix
    { ops.keyFiles = [ ../keys/tcurdt.pub ]; }

    # { users.users.root.password = "secret"; }

    ../modules/rke2-server.nix
  ];

  my.builders.allow = "remote";

  networking.hostId = "7ec474b0";

  networking.firewall.allowedTCPPorts = [
    # 53 # dns
    80 # http
    443 # https
    # 5432 # postgres
    # 8081 # sqld http
    # 5001 # sqld grpc
  ];

  services.my.mmdb = {
    enable = true;
    # daysBetweenUpdates = 3;
  };

}
