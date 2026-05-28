{
  # pkgs,
  # inputs,
  ...
}:
{

  networking.hostName = "k3s-server";
  system.stateVersion = "26.05";

  imports = [

    ../hardware/hetzner-efi.nix
    ../modules/server.nix

    ../users/root.nix
    ../users/ops.nix
    { ops.keyFiles = [ ../keys/tcurdt.pub ]; }

    # { users.users.root.password = "secret"; }

    ../modules/mmdb.nix
    ../modules/k3s-server.nix
  ];

  services.my.mmdb = {
    enable = true;
  };

  services.my.k3s-server = {
    enable = true;
    # floating-ip = {
    #   enable = true;
    #   ipv4 = "116.202.2.78";
    #   ipv6 = "2a01:4f8:1c17:800f::1";
    #   ipv6Gateway = "fe80::1";
    #   interface = "enp1s0";
    # };
  };

}
