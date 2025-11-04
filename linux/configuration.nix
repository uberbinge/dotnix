# linux/configuration.nix
{ config, pkgs, lib, username, ... }:
{
  # Bootloader configuration
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Filesystems
  fileSystems."/" = {
    device = "/dev/disk/by-uuid/e1d7e9fc-77e0-4049-87ea-99a419d0f180";
    fsType = "ext4";
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-uuid/DE25-F348";
    fsType = "vfat";
  };

  # Networking
  networking.hostName = "nixos";

  # Enable Tailscale
  services.tailscale.enable = true;

  # Define the user
  users.users.${username} = {
    isNormalUser = true;
    home = "/home/${username}";
    extraGroups = [ "wheel" "networkmanager" ];
    shell = pkgs.zsh;
  };

  # Font configuration
  fonts.packages = with pkgs; [
    noto-fonts
    noto-fonts-color-emoji
    liberation_ttf
    fira-code
    fira-code-symbols
  ];
  # Enable Zsh
  programs.zsh.enable = true;

  # Nix settings
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nixpkgs.config.allowUnfree = true;

 # Enable the X11 windowing system
 services.xserver.enable = true;
# Enable basic system packages for GNOME
environment.systemPackages = with pkgs; [
  gnome-tweaks
  dconf-editor
  firefox
  xclip
  adwaita-icon-theme
];

# Enable GNOME services
services.gnome.core-apps.enable = true;
services.udev.packages = with pkgs; [ gnome-settings-daemon ];


 # Enable the GNOME Desktop Environment
 services.displayManager.gdm.enable = true;
 services.desktopManager.gnome.enable = true;

 # Configure keymap in X11
 services.xserver.xkb.layout = "us";

  # System state version
  system.stateVersion = "24.05";
}
