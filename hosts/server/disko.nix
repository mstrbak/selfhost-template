{ userConfig, ... }:
{
  disko.devices.disk.main = {
    type = "disk";
    device = userConfig.diskDevice;
    content = {
      type = "gpt";
      partitions = {
        # 1 MiB BIOS Boot Partition for GRUB on legacy-BIOS hosts (Contabo SeaBIOS).
        # Type EF02 = "BIOS boot partition" — no filesystem, GRUB embeds core.img here.
        boot = {
          size = "1M";
          type = "EF02";
          priority = 1;
        };
        root = {
          size = "100%";
          content = {
            type = "filesystem";
            format = "ext4";
            mountpoint = "/";
          };
        };
      };
    };
  };
}
