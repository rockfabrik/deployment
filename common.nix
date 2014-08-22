{ pkgs, ... }:

{
  imports = import ./modules/module-list.nix;

  nix.extraOptions = ''
    build-use-chroot = true
  '';

  environment.systemPackages = with pkgs; [ vim_configurable htop ];

  boot.loader.grub.enable = true;
  boot.loader.grub.version = 2;

  boot.cleanTmpDir = true;

  networking.firewall.enable = false;
  hardware.cpu.intel.updateMicrocode = true;

  nixpkgs.config.allowUnfree = true;

  time.timeZone = "Europe/Berlin";

  users.extraUsers.root.hashedPassword = let
    passwdFile = "/etc/nixos/root.passwd";
    hasPasswdFile = builtins.pathExists passwdFile;
  in if hasPasswdFile then builtins.readFile passwdFile else "";
}
