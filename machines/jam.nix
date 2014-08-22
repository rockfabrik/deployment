{ lib, ... }:

{
  imports = [ ../common.nix ];

  boot.kernelModules = [ "atkbd" ];

  boot.loader.grub = {
    device = "/dev/disk/by-id/ata-SAMSUNG_HD250HJ_S0URJ9AQ109541";
  };

  boot.initrd.availableKernelModules = [
    "uhci_hcd" "ehci_pci" "ata_piix" "usb_storage" "usbhid"
  ];

  hardware.enableAllFirmware = true;

  networking.hostName = "jam";

  fileSystems."/" = {
    device = "/dev/disk/by-uuid/46e9f575-29aa-473c-a587-66d558365df8";
    fsType = "btrfs";
  };

  swapDevices = lib.singleton {
    device = "/dev/disk/by-uuid/58376c8d-5193-4bdd-aa30-4fefdb706733";
  };

  services.xserver.videoDrivers = [ "nouveau" ];

  nix.maxJobs = 2;

  rofa.profiles.dj.enable = true;
}
