{ pkgs, ... }:
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

    ../modules/angie.nix
    ../modules/nginx-selfsigned.nix

  ];

  networking.firewall.allowedTCPPorts = [
    # 53
    80
    443
  ];
  # networking.firewall.allowedUDPPorts = [ 53 ];

  # https://id.vafer.work/setup
  services.pocket-id = {
    enable = true;
    settings = {
      APP_URL = "https://id.vafer.work";
      TRUST_PROXY = true;
      PORT = 8201;
    };
  };

  services.angie = {

    oidcProviders."pocket-id" = {
      discoveryUrl = "https://id.vafer.work/.well-known/openid-configuration";
    };

    virtualHosts."id.vafer.work" = {
      forceSSL = true;
      selfSigned = true;
      locations."/" = {
        proxyPass = "http://127.0.0.1:8201";
        proxyWebsockets = true;
      };
    };

    virtualHosts."test.vafer.work" = {
      forceSSL = true;
      selfSigned = true;
      oidc = {
        provider = "pocket-id";
        clientId = "test-vafer-work";
        secretFile = "/secrets/test-vafer-work-oidc-secret";
      };
      locations."/" = {
        protect = true;
        return = ''200 "hello\n"'';
      };
    };

  };

}
