{
  # pkgs,
  ...
}:
{

  networking.hostName = "home-ber";
  networking.domain = "home";
  system.stateVersion = "25.11";

  imports = [

    ../hardware/lenovo.nix
    ../modules/server.nix

    ../users/root.nix
    ../users/ops.nix
    { ops.keyFiles = [ ../keys/tcurdt.pub ]; }
    # { users.users.root.password = "secret"; }

    ../modules/homeassistant.nix
    ../modules/tailscale.nix
  ];

  services.my.tailscale = {
    enable = true;
    server = "head.vafer.org";
  };

  services.my.homeassistant = {
    enable = true;
    timeZone = "Europe/Berlin";
    server = "ber.tail.vafer.org";
  };

}
