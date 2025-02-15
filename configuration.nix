# Edit this configuration file to define what should be installed on
# your system. Help is available in the configuration.nix(5) man page, on
# https://search.nixos.org/options and in the NixOS manual (`nixos-help`).

{ config, lib, pkgs, ... }:

{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
    ];

  # luks setup
  boot.initrd = {
      luks.devices = {
        luksCrypted = {
          device = "/dev/nvme0n1p3"; # Replace with your UUID
          preLVM = true; # Unlock before activating LVM
          allowDiscards = true; # Allow TRIM commands for SSDs
        };
      };
      #lvm.devices = [ "/dev/mapper/luksCrypted" ]; # Activate LVM after decryption
  };

  # Use the GRUB bootloader
  boot.loader.grub.enable = true;  # Enable GRUB as the bootloader
  boot.loader.grub.device = "nodev";  # Install GRUB on the EFI system partition
  boot.loader.grub.copyKernels = true;  # Activate automatic copying of kernel files
  boot.loader.grub.efiSupport = true;  # Enable EFI support for GRUB
  boot.loader.grub.enableCryptodisk = true ; # Enable GRUB support for encrypted disks
  boot.loader.efi.efiSysMountPoint = "/boot/efi";  # Mount point of the EFI system partition
  boot.loader.efi.canTouchEfiVariables = true;  # Allow GRUB to modify EFI variables for boot entry management
  
  # Adds custom menu entries for reboot and poweroff
  boot.loader.grub.extraEntries = ''
      menuentry "Reboot" {
          reboot
      }
      menuentry "Poweroff" {
          halt
      }
  '';

  # Specify the Zen kernel
  boot.kernelPackages = pkgs.linuxPackages_zen;

  # Add GRUB theme (example using 'sleek-grub-theme')
  # boot.loader.grub.sleekTheme.enable = true;
  # boot.loader.grub.sleekTheme.themeName = "dark";  # Replace with the desired theme name ('dark', 'light', 'orange', 'bigsur')




  networking.hostName = "nixos"; # Define your hostname.
  # Pick only one of the below networking options.

  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.
  networking.networkmanager.enable = true;  # Easiest to use and most distros use this by default.

  # Set your time zone.
  time.timeZone = "Africa/Tunis";

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";
  console = {
    font = "Lat2-Terminus16";
  #  keyMap = "us-colemak-dh";
    useXkbConfig = true; # use xkb.options in tty.
  };

  # Enable the X11 windowing system
  services.xserver.enable = true;

  # Set XKB keyboard layout options
  services.xserver.xkb = {
    layout = "us";                          # Set the keyboard layout to US
    variant = "colemak_dh";                 # Use the Colemak DH variant
    options = "caps:escape, compose:ralt, terminate:ctrl_alt_bksp";  # Set additional XKB options
    # options = "misc:extend,lv5:caps_switch_lock,compose:menu";  # Alternative XKB options (commented out)
  };

  # Enable the KDE Plasma desktop environment
  services.desktopManager.plasma6.enable = true;

  # Enable Wayland for KDE Plasma
  # services.xserver.windowManager.plasma6.enableWayland = true;

  # Enable the SDDM display manager
  services.displayManager.sddm.enable = true;
  services.displayManager.defaultSession = "plasma";  # Set the default session to Plasma Wayland
  # services.displayManager.autoLogin.enable = true;  # Enable auto-login (commented out)
  # services.displayManager.autoLogin.user = "alice";  # Set the auto-login user to 'alice' (commented out)

  # Set GTK/Qt themes
  #qt.enable = true;                 # Enable Qt integration
  #qt.platformTheme = "gtk2";        # Set the platform theme to GTK2
  #qt.style = "gtk2";                # Set the style to GTK2

  # Enable CUPS to print documents.
  services.printing.enable = true;

  # Enable sound.
  # hardware.pulseaudio.enable = true;
  # OR
  services.pipewire = {
    enable = true;
    pulse.enable = true;
  };

  # Enable touchpad support (enabled default in most desktopManager).
  services.libinput.enable = true;



  # Set the default shell for all users to zsh
  # users.defaultShell = pkgs.zsh;

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.titanknis = {
    isNormalUser = true;
    home = "/home/titanknis";
    description = "The system master";
    extraGroups = [ "wheel" "networkmanager" ]; # Enable ‘sudo’ for the user.
  #   openssh.authorizedKeys.keys = [ "ssh-dss AAAAB3Nza... alice@foobar" ];

  #   packages = with pkgs; [
  #     firefox
  #     tree
  #   ];
  };

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    firefox # favorite browser
    kitty 
    neovim # editor of choice
    wget # wget is better than curl because it will resume with exponential backoff
    curl # curl is better than wget because it supports more protocols
    git # git version control
  ];


  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  programs.gnupg.agent = {
    enable = true;
    enableSSHSupport = true;
  };

  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  services.openssh.enable = true;

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;

  # Copy the NixOS configuration file and link it from the resulting system
  # (/run/current-system/configuration.nix). This is useful in case you
  # accidentally delete configuration.nix.
  system.copySystemConfiguration = true;

  # This option defines the first version of NixOS you have installed on this particular machine,
  # and is used to maintain compatibility with application data (e.g. databases) created on older NixOS versions.
  #
  # Most users should NEVER change this value after the initial install, for any reason,
  # even if you've upgraded your system to a new NixOS release.
  #
  # This value does NOT affect the Nixpkgs version your packages and OS are pulled from,
  # so changing it will NOT upgrade your system - see https://nixos.org/manual/nixos/stable/#sec-upgrading for how
  # to actually do that.
  #
  # This value being lower than the current NixOS release does NOT mean your system is
  # out of date, out of support, or vulnerable.
  #
  # Do NOT change this value unless you have manually inspected all the changes it would make to your configuration,
  # and migrated your data accordingly.
  #
  # For more information, see `man configuration.nix` or https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion .
  system.stateVersion = "24.05"; # Did you read the comment?

}

