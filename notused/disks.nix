{
  disko.devices = {
    # tmpfs for root
    nodev = {
      "/" = {
        fsType = "tmpfs";
        mountOptions = [
          "size=2G"
        ];
      };
    };
    disk = {
      nvme0 = {
        type = "disk";
        #device = "/dev/disk/by-diskseq/1";
        device = "/dev/disk/by-id/nvme-SPCC_M.2_PCIe_SSD_AA230203NV512G00588";
        content = {
          type = "gpt";
          partitions = {
            ESP = {
              priority = 1;
              name = "ESP";
              start = "1M";
              end = "550MiB";
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
              };
            };
            root = {
              size = "100%";
              content = {
                type = "btrfs";
                extraArgs = [ "-f" ]; # Override existing partition
                # Subvolumes must set a mountpoint in order to be mounted,
                # unless their parent is mounted
                subvolumes = {
                  #"/rootfs" = {
                  #  mountpoint = "/";
                  #};
                  "/persist" = {
                    mountpoint = "/persist";
                  };
                  #"/home" = {
                  #  #mountOptions = [ "compress=zstd" ];
                  #  mountpoint = "/home";
                  #};
                  # Sub(sub)volume doesn't need a mountpoint as its parent is mounted
                  #"/home/user" = { };
                  # Parent is not mounted so the mountpoint must be set
                  "/nix" = {
                    mountOptions = [ "noatime" ];
                    mountpoint = "/nix";
                  };
                  # This subvolume will be created but not mounted
                  #"/test" = { };
                };
              };
            };
          };
        };
      };
    };
  };
}

