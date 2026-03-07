{
  pkgs,
  ...
}:
{
  security.acme = {
    acceptTerms = true;
    defaults = {
      email = "admin@example.com";
      server = "https://acme-staging-v02.api.letsencrypt.org/directory";
    };
  };

  services.nginx = {
    enable = true;
    package = pkgs.angie;

    recommendedGzipSettings = true;
    recommendedOptimisation = true;
    recommendedTlsSettings = true;
    recommendedProxySettings = true;

    # appendHttpConfig = ''
    #   #add_header Content-Security-Policy "script-src 'self'; object-src 'none'; base-uri 'none';" always;
    #   #add_header 'Referrer-Policy' 'origin-when-cross-origin';
    #   #add_header X-Frame-Options DENY;
    #   #add_header X-Content-Type-Options nosniff;
    #   #proxy_cookie_path / "/; secure; HttpOnly; SameSite=strict";
    # '';

    virtualHosts."hello.example.com" = {
      enableACME = true;
      forceSSL = true;
      locations."/".extraConfig = ''
        default_type text/plain;
        return 200 "hello\n";
      '';
    };

  };

}
