{ pkgs, ... }:
{

  networking.hostName = "utm-x86";
  networking.domain = "utm";
  system.stateVersion = "25.11";

  imports = [

    ../hardware/utm-x86.nix
    ../modules/server.nix

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
    53
    80
    443
  ];
  networking.firewall.allowedUDPPorts = [ 53 ];

  services.nginx = {
    enable = true;
    package = pkgs.angieWithAcme;
    virtualHosts = { };
    appendHttpConfig = ''
      resolver 1.1.1.1 8.8.8.8;

      acme_client vafer_work https://acme-staging-v02.api.letsencrypt.org/directory challenge=dns;
      acme_dns_port 53;

      server {
          listen 80;
          server_name test.vafer.work *.branch.vafer.work;
          return 301 https://$host$request_uri;
      }

      server {
          listen 443 ssl;
          server_name test.vafer.work *.branch.vafer.work;

          acme vafer_work;
          ssl_certificate $acme_cert_vafer_work;
          ssl_certificate_key $acme_cert_key_vafer_work;

          location / {
              default_type text/plain;
              return 200 "hello\n";
          }
      }
    '';
  };

  systemd.tmpfiles.rules = [
    "d /var/lib/nginx 0750 nginx nginx -"
    "d /var/lib/nginx/acme 0700 nginx nginx -"
  ];

  systemd.services.nginx.serviceConfig.ReadWritePaths = [
    "/var/lib/nginx"
  ];
}
