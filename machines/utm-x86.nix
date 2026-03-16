{ ... }:
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

  # https://id.vafer.work
  services.authelia.instances.main = {
    enable = true;
    secrets = {
      jwtSecretFile = "/secrets/authelia-jwt";
      storageEncryptionKeyFile = "/secrets/authelia-storage-key";
      sessionSecretFile = "/secrets/authelia-session";
    };
    settings = {
      authentication_backend.file.path = "/etc/authelia/users.yml";
      session.cookies = [
        {
          domain = "vafer.work";
          authelia_url = "https://id.vafer.work";
        }
      ];
      storage.local.path = "/var/lib/authelia-main/db.sqlite3";
      notifier.filesystem.filename = "/var/lib/authelia-main/notifications.txt";
      webauthn = {
        enable_passkey_login = true;
      };
      access_control = {
        default_policy = "one_factor";
      };
    };
  };

  services.angie = {

    virtualHosts."id.vafer.work" = {
      forceSSL = true;
      selfSigned = true;
      locations."/" = {
        proxyPass = "http://127.0.0.1:9091";
      };
    };

    virtualHosts."test.vafer.work" = {
      forceSSL = true;
      selfSigned = true;
      authrequest = "main";
      locations."/" = {
        return = ''200 "hello\n"'';
      };
    };

  };

}
