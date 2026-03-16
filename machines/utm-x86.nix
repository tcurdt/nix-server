{ config, ... }:
{

  networking.hostName = "utm-x86";
  networking.domain = "utm";
  system.stateVersion = "25.11";

  imports = [

    ../hardware/utm-x86.nix
    ../modules/server.nix
    ../modules/mmdb.nix

    ../users/root.nix
    ../users/ops.nix
    { ops.keyFiles = [ ../keys/tcurdt.pub ]; }

    { users.users.root.password = "secret"; }

    ../modules/authelia.nix
    ../modules/angie.nix

  ];

  networking.firewall.allowedTCPPorts = [
    80
    443
  ];

  services.my.authelia = {
    domain = "vafer.work";
    authelia_url = "https://id.vafer.work";
  };

  services.my.angie = {

    virtualHosts."id.vafer.work" = {
      selfSigned = true;
      locations."/" = {
        proxyPass = config.services.my.authelia.url;
      };
    };

    virtualHosts."test.vafer.work" = {
      selfSigned = true;
      authelia = config.services.my.authelia;
      locations."/" = {
        return = ''200 "hello\n"'';
      };
    };

  };
}
