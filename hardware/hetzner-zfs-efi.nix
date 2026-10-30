{
  lib,
  modulesPath,
  ...
}:
{
  imports = [ (modulesPath + "/profiles/qemu-guest.nix") ];

  boot.loader.grub.enable = true;
  boot.loader.grub.efiSupport = true;
  boot.loader.grub.efiInstallAsRemovable = true;
  boot.loader.grub.device = "nodev";

  boot.initrd.availableKernelModules = [
    "ahci"
    "virtio_pci"
    "virtio_scsi"
    "sd_mod"
    "sr_mod"
  ];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";

  disko.devices = {
    disk.main = {
      device = lib.mkDefault "/dev/sda";
      type = "disk";
      imageSize = "11G";
      content = {
        type = "gpt";
        partitions = {
          esp = {
            size = "256M";
            type = "EF00";
            content = {
              type = "filesystem";
              format = "vfat";
              mountpoint = "/boot";
            };
          };
          root = {
            size = "10G";
            content = {
              type = "filesystem";
              format = "ext4";
              mountpoint = "/";
              mountOptions = [ "noatime" ];
              extraArgs = [
                "-L"
                "nixos"
              ];
            };
          };
          varlib = {
            size = "100%";
            content = {
              type = "zfs";
              pool = "varlib";
            };
          };
        };
      };
    };

    zpool.varlib = {
      type = "zpool";
      rootFsOptions = {
        atime = "off";
        compression = "lz4";
        xattr = "sa";
        acltype = "posixacl";
      };
      datasets = {
        data = {
          type = "zfs_fs";
          mountpoint = "/var/lib";
          options.mountpoint = "legacy";
        };
      };
    };
  };
}
