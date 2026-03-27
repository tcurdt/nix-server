{
  pkgs,
  lib,
  config,
  ...
}:

let
  # Required files for primary mode:
  #   /secrets/sqld_ca_cert.pem
  #   /secrets/sqld_server_key.pem
  #   /secrets/sqld_server_cert.pem
  #
  # Minimal local generation example:
  #   openssl genrsa -out /secrets/sqld_ca_key.pem 4096
  #   openssl req -x509 -new -nodes -key /secrets/sqld_ca_key.pem -sha256 -days 3650 -out /secrets/sqld_ca_cert.pem -subj "/CN=sqld-ca"
  #   openssl genrsa -out /secrets/sqld_server_key.pem 2048
  #   openssl req -new -key /secrets/sqld_server_key.pem -out /tmp/sqld_server.csr -subj "/CN=sqld"
  #   openssl x509 -req -in /tmp/sqld_server.csr -CA /secrets/sqld_ca_cert.pem -CAkey /secrets/sqld_ca_key.pem -CAcreateserial -out /secrets/sqld_server_cert.pem -days 825 -sha256
  #   rm -f /tmp/sqld_server.csr

  cfg = config.services.my.sqld;
  inheritOr = value: fallback: if value == null then fallback else value;

  normalizeInstance = _name: instanceCfg: {
    enable = inheritOr instanceCfg.enable cfg.enable;
    user = inheritOr instanceCfg.user cfg.user;
    primary = inheritOr instanceCfg.primary cfg.primary;
    listenAddress = inheritOr instanceCfg.listenAddress cfg.listenAddress;
    ports = {
      http = inheritOr instanceCfg.ports.http cfg.ports.http;
      grpc = inheritOr instanceCfg.ports.grpc cfg.ports.grpc;
    };
    primaryHttpUrl = inheritOr instanceCfg.primaryHttpUrl cfg.primaryHttpUrl;
    primaryGrpcUrl = inheritOr instanceCfg.primaryGrpcUrl cfg.primaryGrpcUrl;
    ca = {
      cert = inheritOr instanceCfg.ca.cert cfg.ca.cert;
    };
    server = {
      cert = inheritOr instanceCfg.server.cert cfg.server.cert;
      key = inheritOr instanceCfg.server.key cfg.server.key;
    };
    client = {
      cert = inheritOr instanceCfg.client.cert cfg.client.cert;
      key = inheritOr instanceCfg.client.key cfg.client.key;
    };
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

  mkSecretCheckScript =
    instance: requiredSecrets:
    pkgs.writeShellScript "sqld-${instance}-check-secrets" ''
      set -euo pipefail
      for path in "$@"; do
        if [ ! -r "$path" ]; then
          echo "sqld ${instance}: missing or unreadable required secret: $path" >&2
          exit 1
        fi
      done
    '';

  mkExecStart =
    instance: instanceCfg:
    let
      httpAddr = "${instanceCfg.listenAddress}:${toString instanceCfg.ports.http}";
      grpcAddr = "${instanceCfg.listenAddress}:${toString instanceCfg.ports.grpc}";
      stateDir = "/var/lib/sqld/${instance}";
    in
    lib.concatStringsSep " " (
      [
        "${pkgs.sqld}/bin/sqld"
        "--db-path ${stateDir}/data.sqld"
        "--http-listen-addr ${httpAddr}"
        "--grpc-listen-addr ${grpcAddr}"
      ]
      ++ lib.optionals instanceCfg.primary [
        "--grpc-tls"
        "--grpc-cert-file ${instanceCfg.server.cert}"
        "--grpc-key-file ${instanceCfg.server.key}"
        "--grpc-ca-cert-file ${instanceCfg.ca.cert}"
      ]
      ++ lib.optionals (!instanceCfg.primary) [
        "--http-primary-url ${instanceCfg.primaryHttpUrl}"
        "--primary-grpc-url ${instanceCfg.primaryGrpcUrl}"
      ]
      ++ lib.optionals (!instanceCfg.primary && instanceCfg.client.cert != null) [
        "--primary-grpc-tls"
        "--primary-grpc-cert-file ${instanceCfg.client.cert}"
      ]
      ++ lib.optionals (!instanceCfg.primary && instanceCfg.client.key != null) [
        "--primary-grpc-key-file ${instanceCfg.client.key}"
      ]
      ++ lib.optionals (!instanceCfg.primary && instanceCfg.ca.cert != null) [
        "--primary-grpc-ca-cert-file ${instanceCfg.ca.cert}"
      ]
    );

  mkService =
    instance: instanceCfg:
    let
      requiredSecrets =
        lib.optionals instanceCfg.primary [
          instanceCfg.ca.cert
          instanceCfg.server.cert
          instanceCfg.server.key
        ]
        ++ lib.optionals (!instanceCfg.primary && instanceCfg.client.cert != null) [
          instanceCfg.client.cert
        ]
        ++ lib.optionals (!instanceCfg.primary && instanceCfg.client.key != null) [ instanceCfg.client.key ]
        ++ lib.optionals (!instanceCfg.primary && instanceCfg.ca.cert != null) [ instanceCfg.ca.cert ];
    in
    {
      description = "sqld ${instance} server";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        ExecStart = mkExecStart instance instanceCfg;
        ExecStartPre = lib.optional (requiredSecrets != [ ]) (
          "${mkSecretCheckScript instance requiredSecrets} ${lib.escapeShellArgs requiredSecrets}"
        );
        Type = "simple";
        User = instanceCfg.user;
        Group = instanceCfg.user;
        StateDirectory = "sqld/${instance}";
        StateDirectoryMode = "0750";
        WorkingDirectory = "/var/lib/sqld/${instance}";
        Restart = "always";
      };
    };

  replicaAssertions = lib.mapAttrsToList (instance: instanceCfg: {
    assertion =
      instanceCfg.primary || (instanceCfg.primaryHttpUrl != null && instanceCfg.primaryGrpcUrl != null);
    message = "services.my.sqld.instances.${instance}: replica instances require both primaryHttpUrl and primaryGrpcUrl.";
  }) enabledInstances;
in
{
  options.services.my.sqld = lib.mkOption {
    default = { };
    description = "sqld service defaults and instances.";
    type = lib.types.submodule {
      options = {
        enable = lib.mkEnableOption "sqld";

        user = lib.mkOption {
          type = lib.types.str;
          default = "sqld";
          description = "Default system user/group for sqld instances.";
        };

        primary = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Whether sqld instances act as primary by default.";
        };

        listenAddress = lib.mkOption {
          type = lib.types.str;
          default = "127.0.0.1";
          description = "Default address to bind HTTP and gRPC listeners to.";
        };

        ports = {
          http = lib.mkOption {
            type = lib.types.port;
            default = 8080;
          };
          grpc = lib.mkOption {
            type = lib.types.port;
            default = 5001;
          };
        };

        primaryHttpUrl = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "Default HTTP URL of the primary node when an instance is a replica.";
        };

        primaryGrpcUrl = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "Default gRPC URL of the primary node when an instance is a replica.";
        };

        ca = {
          cert = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
          };
        };

        server = {
          cert = lib.mkOption {
            type = lib.types.str;
            default = "";
          };
          key = lib.mkOption {
            type = lib.types.str;
            default = "";
          };
        };

        client = {
          cert = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
          };
          key = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
          };
        };

        instances = lib.mkOption {
          default = { };
          description = "sqld instances keyed by instance name.";
          type = lib.types.attrsOf (
            lib.types.submodule {
              options = {
                enable = lib.mkOption {
                  type = lib.types.nullOr lib.types.bool;
                  default = null;
                  description = "Whether this instance is enabled. Null inherits services.my.sqld.enable.";
                };

                user = lib.mkOption {
                  type = lib.types.nullOr lib.types.str;
                  default = null;
                  description = "System user/group for this instance. Null inherits services.my.sqld.user.";
                };

                primary = lib.mkOption {
                  type = lib.types.nullOr lib.types.bool;
                  default = null;
                  description = "Whether this sqld instance acts as primary. Null inherits services.my.sqld.primary.";
                };

                listenAddress = lib.mkOption {
                  type = lib.types.nullOr lib.types.str;
                  default = null;
                  description = "Address to bind HTTP and gRPC listeners to. Null inherits services.my.sqld.listenAddress.";
                };

                ports = {
                  http = lib.mkOption {
                    type = lib.types.nullOr lib.types.port;
                    default = null;
                  };
                  grpc = lib.mkOption {
                    type = lib.types.nullOr lib.types.port;
                    default = null;
                  };
                };

                primaryHttpUrl = lib.mkOption {
                  type = lib.types.nullOr lib.types.str;
                  default = null;
                  description = "HTTP URL of the primary node when this instance is a replica. Null inherits services.my.sqld.primaryHttpUrl.";
                };

                primaryGrpcUrl = lib.mkOption {
                  type = lib.types.nullOr lib.types.str;
                  default = null;
                  description = "gRPC URL of the primary node when this instance is a replica. Null inherits services.my.sqld.primaryGrpcUrl.";
                };

                ca = {
                  cert = lib.mkOption {
                    type = lib.types.nullOr lib.types.str;
                    default = null;
                  };
                };

                server = {
                  cert = lib.mkOption {
                    type = lib.types.nullOr lib.types.str;
                    default = null;
                  };
                  key = lib.mkOption {
                    type = lib.types.nullOr lib.types.str;
                    default = null;
                  };
                };

                client = {
                  cert = lib.mkOption {
                    type = lib.types.nullOr lib.types.str;
                    default = null;
                  };
                  key = lib.mkOption {
                    type = lib.types.nullOr lib.types.str;
                    default = null;
                  };
                };
              };
            }
          );
        };
      };
    };
  };

  config = lib.mkIf (enabledInstances != { }) {
    assertions =
      replicaAssertions
      ++ lib.mapAttrsToList (instance: instanceCfg: {
        assertion =
          (!instanceCfg.primary)
          || (instanceCfg.server.cert != "" && instanceCfg.server.key != "" && instanceCfg.ca.cert != null);
        message = "services.my.sqld.instances.${instance}: primary instances require server.cert, server.key and ca.cert.";
      }) enabledInstances;

    users.groups = lib.listToAttrs (map (user: lib.nameValuePair user { }) enabledUsers);

    users.users = lib.listToAttrs (
      map (
        user:
        lib.nameValuePair user {
          isSystemUser = true;
          group = user;
          home = "/var/lib/sqld";
        }
      ) enabledUsers
    );

    systemd.services = lib.mapAttrs' (
      instance: instanceCfg: lib.nameValuePair "sqld-${instance}" (mkService instance instanceCfg)
    ) enabledInstances;
  };
}
