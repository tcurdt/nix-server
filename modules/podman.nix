{ config, lib, ... }:

let
  cfg = config.services.my.podman;
  podman = config.virtualisation.podman.package;
  containers = config.virtualisation.oci-containers.containers;
  networkUnit = name: "podman-network-${name}.service";
in {
  options.services.my.podman = {
    enable = lib.mkEnableOption "podman as the oci-containers backend";

    networks = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule {
        options.subnet = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          example = "10.89.10.0/24";
          description = "Subnet for the network. Null lets podman pick one.";
        };
      });
      default = { };
      example = { app = { }; };
      description = ''
        Podman bridge networks to create. Containers join one via
        `virtualisation.oci-containers.containers.<name>.networks` and can
        reach each other by container name.
      '';
    };
  };

  config = lib.mkIf cfg.enable {

    virtualisation = {
      containers.enable = true;
      oci-containers.backend = "podman";
      podman = {
        enable = true;
        # also opens DNS (53) on all podman+ interfaces, needed for name resolution between containers
        defaultNetwork.settings.dns_enabled = true;
        autoPrune = {
          enable = true;
          dates = "weekly";
          flags = [ "--all" ];
        };
      };
    };

    environment.systemPackages = [ podman ];

    systemd.services = lib.mkMerge [

      # one oneshot unit per network
      (lib.mapAttrs' (name: net:
        lib.nameValuePair "podman-network-${name}" {
          description = "podman network ${name}";
          wantedBy = [ "multi-user.target" ];
          path = [ podman ];
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
          };
          script = lib.escapeShellArgs
            ([ "podman" "network" "create" "--ignore" ]
              ++ lib.optional (net.subnet != null) "--subnet=${net.subnet}"
              ++ [ name ]);
        }) cfg.networks)

      # containers start after the networks they join
      (lib.mapAttrs' (_: c:
        let
          units = map networkUnit
            (builtins.filter (n: cfg.networks ? ${n}) c.networks);
        in lib.nameValuePair c.serviceName {
          requires = units;
          after = units;
        }) containers)
    ];
  };
}
