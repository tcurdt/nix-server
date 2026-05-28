{
  config,
  lib,
  ...
}:

let
  cfg = config.services.my.cache-oci;
in
{
  options.services.my.cache-oci = {
    enable = lib.mkEnableOption "LAN-local OCI registry cache";

    address = lib.mkOption {
      type = lib.types.str;
      default = "10.0.0.2";
      description = "LAN-local address the OCI registry listens on.";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 5000;
      description = "Port the OCI registry listens on.";
    };

    storagePath = lib.mkOption {
      type = lib.types.path;
      default = "/var/lib/registry";
      description = "Filesystem storage path for registry blobs.";
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Whether to open the registry port in the firewall.";
    };

    enableDelete = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Whether the registry allows deleting manifests and blobs.";
    };

    enableGarbageCollect = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to periodically run registry garbage collection.";
    };

    garbageCollectDates = lib.mkOption {
      type = lib.types.str;
      default = "daily";
      description = "Systemd calendar expression for registry garbage collection.";
    };

    htpasswdFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      example = "/secrets/registry-htpasswd";
      description = "Optional htpasswd file for registry basic authentication.";
    };

    extraConfig = lib.mkOption {
      type = lib.types.attrs;
      default = { };
      description = "Extra docker registry configuration merged into services.dockerRegistry.extraConfig.";
    };
  };

  config = lib.mkIf cfg.enable {
    services.dockerRegistry = {
      enable = true;
      listenAddress = cfg.address;
      port = cfg.port;
      storagePath = cfg.storagePath;
      openFirewall = cfg.openFirewall;
      enableDelete = cfg.enableDelete;
      enableGarbageCollect = cfg.enableGarbageCollect;
      garbageCollectDates = cfg.garbageCollectDates;
      extraConfig = lib.recursiveUpdate cfg.extraConfig (
        lib.optionalAttrs (cfg.htpasswdFile != null) {
          auth.htpasswd = {
            realm = "registry";
            path = cfg.htpasswdFile;
          };
        }
      );
    };
  };
}
