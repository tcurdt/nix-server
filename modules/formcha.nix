{
  pkgs,
  lib,
  config,
  inputs,
  ...
}:

let
  cfg = config.services.my.formcha;
  package = inputs.formcha.packages.${pkgs.stdenv.hostPlatform.system}.default;
  inheritOr = value: fallback: if value == null then fallback else value;

  normalizeInstance = name: instanceCfg: {
    enable = inheritOr instanceCfg.enable cfg.enable;
    user = inheritOr instanceCfg.user cfg.user;
    server = inheritOr instanceCfg.server cfg.server;
    url = "http://unix:${mkSocketPath name}:";
    idleTimeout = inheritOr instanceCfg.idleTimeout cfg.idleTimeout;
    altchaHmacKeyFile = inheritOr instanceCfg.altchaHmacKeyFile cfg.altchaHmacKeyFile;
    smtp = inheritOr instanceCfg.smtp cfg.smtp;
    webhook = inheritOr instanceCfg.webhook cfg.webhook;
    brevo = inheritOr instanceCfg.brevo cfg.brevo;
    pushover = inheritOr instanceCfg.pushover cfg.pushover;
    ntfy = inheritOr instanceCfg.ntfy cfg.ntfy;
  };

  effectiveInstances =
    if cfg.instances != { } then
      lib.mapAttrs normalizeInstance cfg.instances
    else
      {
        main = normalizeInstance "main" cfg;
      };

  enabledInstances = lib.filterAttrs (_: instance: instance.enable) effectiveInstances;
  enabledUsers = lib.unique (
    map (instanceCfg: instanceCfg.user) (builtins.attrValues enabledInstances)
  );

  mkSocketPath = instance: "/run/formcha/${instance}.sock";
  mkConfigPath = instance: "/run/formcha/${instance}.yaml";

  # Read a file and escape its contents for use in a YAML double-quoted string.
  readSecret = file: ''$(sed 's/\\/\\\\/g; s/"/\\"/g' ${lib.escapeShellArg file})'';

  mkPreStart =
    name: instanceCfg:
    let
      configPath = mkConfigPath name;
      s = lib.escapeShellArg;
    in
    ''
      mkdir -p /run/formcha
      truncate -s0 ${s configPath}
      chmod 600 ${s configPath}
    ''
    + lib.optionalString (instanceCfg.idleTimeout != null) ''
      printf 'server:\n  idle_timeout: "%s"\n' ${s instanceCfg.idleTimeout} >> ${s configPath}
    ''
    + lib.optionalString (instanceCfg.altchaHmacKeyFile != null) ''
      printf 'altcha:\n  hmac_key: "%s"\n' "${readSecret instanceCfg.altchaHmacKeyFile}" >> ${s configPath}
    ''
    + lib.optionalString (instanceCfg.smtp != null) (
      let
        smtp = instanceCfg.smtp;
      in
      ''
        printf 'smtp:\n  host: "%s"\n  port: "%s"\n  username: "%s"\n  from: "%s"\n  to: "%s"\n' \
          ${s smtp.host} ${s smtp.port} ${s smtp.username} ${s smtp.from} ${s smtp.to} >> ${s configPath}
      ''
      + lib.optionalString (smtp.passwordFile != null) ''
        printf '  password: "%s"\n' "${readSecret smtp.passwordFile}" >> ${s configPath}
      ''
    )
    + lib.optionalString (instanceCfg.webhook != null) ''
      printf 'webhook:\n  url: "%s"\n' ${s instanceCfg.webhook.url} >> ${s configPath}
    ''
    + lib.optionalString (instanceCfg.brevo != null) (
      let
        brevo = instanceCfg.brevo;
      in
      ''
        printf 'brevo:\n  sender_name: "%s"\n  sender_email: "%s"\n  to_email: "%s"\n  to_name: "%s"\n' \
          ${s brevo.sender_name} ${s brevo.sender_email} ${s brevo.to_email} ${s brevo.to_name} >> ${s configPath}
      ''
      + lib.optionalString (brevo.apiKeyFile != null) ''
        printf '  api_key: "%s"\n' "${readSecret brevo.apiKeyFile}" >> ${s configPath}
      ''
    )
    + lib.optionalString (instanceCfg.pushover != null) (
      let
        pushover = instanceCfg.pushover;
      in
      ''
        printf 'pushover:\n' >> ${s configPath}
      ''
      + lib.optionalString (pushover.tokenFile != null) ''
        printf '  token: "%s"\n' "${readSecret pushover.tokenFile}" >> ${s configPath}
      ''
      + lib.optionalString (pushover.userKeyFile != null) ''
        printf '  user_key: "%s"\n' "${readSecret pushover.userKeyFile}" >> ${s configPath}
      ''
    )
    + lib.optionalString (instanceCfg.ntfy != null) (
      let
        ntfy = instanceCfg.ntfy;
      in
      ''
        printf 'ntfy:\n  url: "%s"\n' ${s ntfy.url} >> ${s configPath}
      ''
      + lib.optionalString (ntfy.tokenFile != null) ''
        printf '  token: "%s"\n' "${readSecret ntfy.tokenFile}" >> ${s configPath}
      ''
    );

  mkSocket = instance: _instanceCfg: {
    description = "formcha ${instance} server socket";
    partOf = [ "formcha-${instance}.service" ];
    wantedBy = [ "sockets.target" ];
    socketConfig = {
      ListenStream = mkSocketPath instance;
      Backlog = 128;
      DirectoryMode = "0770";
      SocketMode = "0660";
      SocketGroup = "nginx";
    };
  };

  mkService = instance: instanceCfg: {
    description = "formcha ${instance} server";
    after = [ "network.target" ];
    unitConfig.ConditionPathExists = lib.optional (
      instanceCfg.altchaHmacKeyFile != null
    ) instanceCfg.altchaHmacKeyFile;
    preStart = mkPreStart instance instanceCfg;
    serviceConfig = {
      ExecStart = "${package}/bin/formcha --config ${mkConfigPath instance}";
      Type = "simple";
      User = instanceCfg.user;
      Group = instanceCfg.user;
    };
  };

  smtpOptions = {
    host = lib.mkOption {
      type = lib.types.str;
      description = "SMTP host.";
    };
    port = lib.mkOption {
      type = lib.types.str;
      default = "587";
      description = "SMTP port.";
    };
    username = lib.mkOption {
      type = lib.types.str;
      description = "SMTP username.";
    };
    passwordFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "File containing the SMTP password.";
    };
    from = lib.mkOption {
      type = lib.types.str;
      description = "Sender address.";
    };
    to = lib.mkOption {
      type = lib.types.str;
      description = "Recipient address.";
    };
  };

  instanceOptions =
    { ... }:
    {
      options = {
        enable = lib.mkOption {
          type = lib.types.nullOr lib.types.bool;
          default = null;
          description = "Whether this instance is enabled. Null inherits services.my.formcha.enable.";
        };

        user = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "System user/group. Null inherits services.my.formcha.user.";
        };

        server = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "Public server name for nginx. Null inherits services.my.formcha.server.";
        };

        url = lib.mkOption {
          type = lib.types.str;
          internal = true;
          readOnly = true;
          default = "";
          description = "Derived URL for proxying to this instance (Unix socket).";
        };

        idleTimeout = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          example = "30s";
          description = "Server idle timeout. Null inherits services.my.formcha.idleTimeout.";
        };

        altchaHmacKeyFile = lib.mkOption {
          type = lib.types.nullOr lib.types.path;
          default = "/secrets/formcha-altcha-hmac-key";
          description = "File containing the ALTCHA HMAC key. Null inherits services.my.formcha.altchaHmacKeyFile.";
        };

        smtp = lib.mkOption {
          type = lib.types.nullOr (lib.types.submodule { options = smtpOptions; });
          default = null;
          description = "SMTP backend. Null inherits services.my.formcha.smtp.";
        };

        webhook = lib.mkOption {
          type = lib.types.nullOr (
            lib.types.submodule {
              options.url = lib.mkOption {
                type = lib.types.str;
                description = "Webhook URL.";
              };
            }
          );
          default = null;
          description = "Webhook backend. Null inherits services.my.formcha.webhook.";
        };

        brevo = lib.mkOption {
          type = lib.types.nullOr (
            lib.types.submodule {
              options = {
                apiKeyFile = lib.mkOption {
                  type = lib.types.nullOr lib.types.path;
                  default = null;
                  description = "File containing the Brevo API key.";
                };
                sender_name = lib.mkOption {
                  type = lib.types.str;
                  description = "Sender name.";
                };
                sender_email = lib.mkOption {
                  type = lib.types.str;
                  description = "Sender email.";
                };
                to_email = lib.mkOption {
                  type = lib.types.str;
                  description = "Recipient email.";
                };
                to_name = lib.mkOption {
                  type = lib.types.str;
                  description = "Recipient name.";
                };
              };
            }
          );
          default = null;
          description = "Brevo backend. Null inherits services.my.formcha.brevo.";
        };

        pushover = lib.mkOption {
          type = lib.types.nullOr (
            lib.types.submodule {
              options = {
                tokenFile = lib.mkOption {
                  type = lib.types.nullOr lib.types.path;
                  default = null;
                  description = "File containing the Pushover application token.";
                };
                userKeyFile = lib.mkOption {
                  type = lib.types.nullOr lib.types.path;
                  default = null;
                  description = "File containing the Pushover user key.";
                };
              };
            }
          );
          default = null;
          description = "Pushover backend. Null inherits services.my.formcha.pushover.";
        };

        ntfy = lib.mkOption {
          type = lib.types.nullOr (
            lib.types.submodule {
              options = {
                url = lib.mkOption {
                  type = lib.types.str;
                  description = "ntfy topic URL.";
                };
                tokenFile = lib.mkOption {
                  type = lib.types.nullOr lib.types.path;
                  default = null;
                  description = "File containing the ntfy access token.";
                };
              };
            }
          );
          default = null;
          description = "ntfy backend. Null inherits services.my.formcha.ntfy.";
        };
      };
    };
in
{
  imports = [
    ./nginx.nix
  ];

  options.services.my.formcha = lib.mkOption {
    default = { };
    description = "formcha service defaults and instances.";
    type = lib.types.submodule (
      { ... }:
      {
        options = {
          enable = lib.mkEnableOption "formcha";

          user = lib.mkOption {
            type = lib.types.str;
            default = "formcha";
            description = "Default system user/group for formcha instances.";
          };

          server = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            example = "formcha.example.org";
            description = "Default public server name. Null disables nginx registration.";
          };

          url = lib.mkOption {
            type = lib.types.str;
            internal = true;
            readOnly = true;
            default = "http://unix:${mkSocketPath "main"}:";
            description = "Derived URL alias for the main formcha instance.";
          };

          idleTimeout = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            example = "30s";
            description = "Default server idle timeout.";
          };

          altchaHmacKeyFile = lib.mkOption {
            type = lib.types.nullOr lib.types.path;
            default = null;
            description = "Default file containing the ALTCHA HMAC key.";
          };

          smtp = lib.mkOption {
            type = lib.types.nullOr (lib.types.submodule { options = smtpOptions; });
            default = null;
            description = "Default SMTP backend.";
          };

          webhook = lib.mkOption {
            type = lib.types.nullOr (
              lib.types.submodule {
                options.url = lib.mkOption {
                  type = lib.types.str;
                  description = "Webhook URL.";
                };
              }
            );
            default = null;
            description = "Default webhook backend.";
          };

          brevo = lib.mkOption {
            type = lib.types.nullOr (
              lib.types.submodule {
                options = {
                  apiKeyFile = lib.mkOption {
                    type = lib.types.nullOr lib.types.path;
                    default = null;
                    description = "File containing the Brevo API key.";
                  };
                  sender_name = lib.mkOption {
                    type = lib.types.str;
                    description = "Sender name.";
                  };
                  sender_email = lib.mkOption {
                    type = lib.types.str;
                    description = "Sender email.";
                  };
                  to_email = lib.mkOption {
                    type = lib.types.str;
                    description = "Recipient email.";
                  };
                  to_name = lib.mkOption {
                    type = lib.types.str;
                    description = "Recipient name.";
                  };
                };
              }
            );
            default = null;
            description = "Default Brevo backend.";
          };

          pushover = lib.mkOption {
            type = lib.types.nullOr (
              lib.types.submodule {
                options = {
                  tokenFile = lib.mkOption {
                    type = lib.types.nullOr lib.types.path;
                    default = null;
                    description = "File containing the Pushover application token.";
                  };
                  userKeyFile = lib.mkOption {
                    type = lib.types.nullOr lib.types.path;
                    default = null;
                    description = "File containing the Pushover user key.";
                  };
                };
              }
            );
            default = null;
            description = "Default Pushover backend.";
          };

          ntfy = lib.mkOption {
            type = lib.types.nullOr (
              lib.types.submodule {
                options = {
                  url = lib.mkOption {
                    type = lib.types.str;
                    description = "ntfy topic URL.";
                  };
                  tokenFile = lib.mkOption {
                    type = lib.types.nullOr lib.types.path;
                    default = null;
                    description = "File containing the ntfy access token.";
                  };
                };
              }
            );
            default = null;
            description = "Default ntfy backend.";
          };

          instances = lib.mkOption {
            default = { };
            description = "formcha instances keyed by instance name.";
            type = lib.types.attrsOf (lib.types.submodule instanceOptions);
          };
        };
      }
    );
  };

  config = lib.mkIf (enabledInstances != { }) {
    users.groups = lib.listToAttrs (map (user: lib.nameValuePair user { }) enabledUsers);

    users.users = lib.listToAttrs (
      map (
        user:
        lib.nameValuePair user {
          isSystemUser = true;
          group = user;
        }
      ) enabledUsers
    );

    systemd.sockets = lib.mapAttrs' (
      instance: instanceCfg: lib.nameValuePair "formcha-${instance}" (mkSocket instance instanceCfg)
    ) enabledInstances;

    systemd.services = lib.mapAttrs' (
      instance: instanceCfg: lib.nameValuePair "formcha-${instance}" (mkService instance instanceCfg)
    ) enabledInstances;

    services.my.nginx =
      lib.mkIf (lib.any (instanceCfg: instanceCfg.server != null) (builtins.attrValues enabledInstances))
        {
          enable = true;
          virtualHosts = lib.listToAttrs (
            lib.mapAttrsToList (
              _instance: instanceCfg:
              lib.nameValuePair instanceCfg.server {
                locations."/" = {
                  proxyPass = instanceCfg.url;
                };
              }
            ) (lib.filterAttrs (_: instanceCfg: instanceCfg.server != null) enabledInstances)
          );
        };
  };
}
