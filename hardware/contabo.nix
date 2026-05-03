{
  lib,
  modulesPath,
  ...
}:
{
  imports = [ (modulesPath + "/profiles/qemu-guest.nix") ];

  boot.loader.grub.enable = true;
  boot.loader.grub.device = "/dev/sda";

  boot.initrd.availableKernelModules = [
    "ata_piix"
    "uhci_hcd"
    "xen_blkfront"
    "vmw_pvscsi"
  ];
  boot.initrd.kernelModules = [ "nvme" ];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";

  disko.devices = {
    disk.main = {
      device = lib.mkDefault "/dev/sda";
      type = "disk";
      imageSize = "11G";
      content = {
        type = "gpt";
        partitions = {
          bios = {
            size = "1M";
            type = "EF02";
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
