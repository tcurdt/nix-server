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

  ];

  nixpkgs.overlays = [
    (final: prev: {
      angieWithAcme = prev.angie.override { withAcme = true; };
    })
  ];

  networking.firewall.allowedTCPPorts = [
    # 53
    80
    443
  ];
  networking.firewall.allowedUDPPorts = [ 53 ];

  services.pocket-id = {
    enable = true;
    settings = {
      APP_URL = "https://id.vafer.work";
      TRUST_PROXY = true;
      PORT = 8201;
    };
  };

  services.nginx = {
    enable = true;
    package = pkgs.angieWithAcme;
    # appendHttpConfig = ''
    #   resolver 1.1.1.1 8.8.8.8;
    #   acme_client vafer_work https://acme-staging-v02.api.letsencrypt.org/directory challenge=http;
    # '';
    virtualHosts = {
      "id.vafer.work" = {
        # forceSSL = true;
        # sslCertificate = "/var/lib/nginx/selfsigned.crt";
        # sslCertificateKey = "/var/lib/nginx/selfsigned.key";
        # extraConfig = ''
        #   acme vafer_work;
        #   ssl_certificate $acme_cert_vafer_work;
        #   ssl_certificate_key $acme_cert_key_vafer_work;
        # '';
        locations."/" = {
          proxyPass = "http://127.0.0.1:8201";
          proxyWebsockets = true;
        };
      };
    };
  };

  systemd.tmpfiles.rules = [
    "d /var/lib/nginx 0750 nginx nginx -"
    "d /var/lib/nginx/acme 0700 nginx nginx -"
  ];

  systemd.services.nginx.serviceConfig.ReadWritePaths = [
    "/var/lib/nginx"
  ];
}
