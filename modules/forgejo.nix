{
  # pkgs,
  ...
}:
{

  systemd.services.forgejo-bootstrap-oidc = {
    wantedBy = [ "multi-user.target" ];
    after = [ "forgejo.service" ];
    requires = [ "forgejo.service" ];
    serviceConfig = {
      Type = "oneshot";
      User = "forgejo";
      Group = "forgejo";
    };
    script = ''
      forgejo admin auth list --config /var/lib/forgejo/custom/conf/app.ini | grep -q pocket-id || \
        forgejo admin auth add-oauth \
          --config /var/lib/forgejo/custom/conf/app.ini \
          --name pocket-id \
          --provider openidConnect \
          --key forgejo \
          --secret "$(cat /secrets/forgejo-oidc-client-secret)" \
          --auto-discover-url https://id.vafer.org/.well-known/openid-configuration
    '';
  };
}
