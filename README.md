
# NixOS Installation Guide

**Table of Contents:**

1. [Preface](#preface)
2. [Installation Media](#installation-media)
3. [System Configuration](#system-configuration)
4. [Connect to WiFi](#1-connect-to-wifi)
5. [Partition the Disk Using `parted`](#2-partition-the-disk-using-parted)
6. [Format Partitions](#3-format-partitions)
7. [Mount Partitions](#4-mount-partitions)
8. [Generate NixOS Configuration and Install](#5-generate-nixos-configuration-and-install)
9. [Troubleshooting](#troubleshooting)

---

## Preface

**Requirements for this guide:**

- **LVM disk partitioning** for flexibility in storage management.
- **LUKS encryption** for the entire LVM physical volume for security.
- **UEFI boot loader** and **boot partition**.
- **Unencrypted boot partition** to allow GRUB to access its files, especially themes.
- **USB stick installation**.
- **Connecting to the internet using WiFi** (specifically WPA) instead of Ethernet.
- **Full disk installation only**; no dual boot.

**Important:** All commands should be executed as the root user. To gain root access, use:
```sh
sudo -i
```

**Note:** For the most part, installing NixOS is straightforward if you follow this guide. However, a basic understanding of the Nix language is essential. NixOS is deeply integrated with Nix, and you'll need to learn it to create your own configuration or modify an existing one to suit your preferences.

I won’t be covering Nix language fundamentals in this guide. If you have a basic understanding, my example configuration file should be clear and helpful. Learning the basics of Nix is not difficult—it’s quite accessible and easy to grasp. For an introduction, you can refer to the [Nix Language Tutorial](https://nix.dev/tutorials/nix-language.html).


---

## Installation Media

1. **Download the 64-bit minimal install CD** from the [NixOS downloads page](https://nixos.org/download.html).

2. **Verify the ISO Integrity**

   - Download the SHA256 checksum file from the same page.
   - Place both the ISO and checksum file in the same folder.
   - Run:

     ```sh
     sha256sum -c <checksum-file>
     ```

   - Ensure the output indicates that the ISO file is `OK`. If the verification fails, redownload the ISO and checksum files and repeat the verification process.

3. **Create a Bootable USB Stick**

   - Consider using [Ventoy](https://www.ventoy.net/en/index.html) for flexibility.
   - Alternatively, use the command line:

     1. Identify your USB stick:

        ```sh
        lsblk
        ```

     2. Copy the ISO to the USB stick (replace `$DISK` with your USB stick):

        ```sh
        sudo dd if=<ISO_FILE> of=$DISK bs=1M status=progress
        ```

        **Note:** This command will erase all data on the USB stick. Replace `<ISO_FILE>` with the name of your ISO file.

---


## System Configuration

Some UEFI system settings need to be adjusted for NixOS installation. To find the exact steps for your machine, do a quick web search for your model. For example, on my HP, you press `F12` at boot to access the UEFI menu.

Once in the menu:

1. **Ensure Safe Boot is Disabled**.
2. **Ensure Fast Boot is Disabled**.
3. **Ensure UEFI Mode is Enabled**.
4. **Ensure Boot from USB is Enabled**.


---

## Installation

With your UEFI setup complete, it's time to boot from the installation media. On HP machines, press `F9` during startup to access the boot menu and select the USB device. Note that this process may vary depending on your hardware.

---

## 1. Connect to WiFi

1. **Start `wpa_supplicant` and configure WiFi with `wpa_cli`:**
   ```sh
   sudo systemctl start wpa_supplicant
   wpa_cli
   ```

   Inside `wpa_cli`, enter:
   ```sh
   add_network
   0
   set_network 0 ssid "myhomenetwork"
   OK
   set_network 0 psk "mypassword"
   OK
   set_network 0 key_mgmt WPA-PSK
   OK
   enable_network 0
   OK
   ```

   Then, exit `wpa_cli`:
   ```sh
   quit
   ```

---

## 2. Partition the Disk Using `parted`

**Warning:** Partitioning will erase all data on the disk. Ensure you have backed up any important data before proceeding.

1. **Start `parted` in interactive mode:**

   ```sh
   parted /dev/nvme0n1
   ```

   Replace `/dev/nvme0n1` with your actual disk identifier if different.

2. **Create a new GPT partition table:**

   ```sh
   (parted) mklabel gpt
   ```

   This command sets up the disk to use the GPT partitioning scheme, which is necessary for UEFI systems.

3. **Create the partitions:**

   - **Create the EFI System Partition (ESP) (1 MiB to 1 GiB):**
     
     ```sh
     (parted) mkpart ESP fat32 1MiB 1GiB
     (parted) set 1 esp on
     ```

     This sets up a 1 GiB partition formatted as FAT32 for the EFI system. It’s required for UEFI booting.

   - **Create the BOOT partition (1 GiB to 2 GiB):**

     ```sh
     (parted) mkpart BOOT ext4 1GiB 2GiB
     ```

     This sets up a 1 GiB partition formatted as ext4 for the boot loader files.

   - **Create the LUKS encrypted partition (2 GiB to end - 1 MiB):**

     ```sh
     (parted) mkpart LUKS 2GiB -1MiB
     ```

     This creates the remaining space on the disk for LUKS encryption.

4. **Print the partition table to verify:**

   ```sh
   (parted) print
   ```

5. **Quit `parted`:**

   ```sh
   (parted) quit
   ```

---


### 3. Format Partitions

**Format the ESP partition (1 MiB to 1 GiB) as FAT32:**

```bash
mkfs.fat -F32 -n ESP /dev/nvme0n1p1
```

**Format the BOOT partition (1 GiB to 2 GiB) as ext4:**

```bash
mkfs.ext4 -L nixos-boot /dev/nvme0n1p2
```

**Initialize the LUKS encrypted partition (2 GiB to end - 1 MiB):**

```bash
cryptsetup luksFormat /dev/nvme0n1p3
```

**Open the LUKS partition:**

```bash
cryptsetup open /dev/nvme0n1p3 luksCrypted
```

**Create LVM physical volume on the decrypted partition:**

```bash
pvcreate /dev/mapper/luksCrypted
```

**Create an LVM volume group (e.g., vg0):**

```bash
vgcreate vg0 /dev/mapper/luksCrypted
```

**Create logical volumes in the following order:**

- **Create root volume (30 GiB, adjust based on your requirements):**

  ```bash
  lvcreate -L 30G -n nixos-root vg0
  ```

- **Create home volume (50 GiB, adjust based on your requirements):**

  ```bash
  lvcreate -L 50G -n nixos-home vg0
  ```

- **Create swap volume (20 GiB, adjust based on your requirements; should be at least the size of your RAM if you intend to use hibernation):**

  ```bash
  lvcreate -L 20G -n nixos-swap vg0
  ```

**Format logical volumes:**

- **Format root volume as ext4:**

  ```bash
  mkfs.ext4 -L nixos-root /dev/vg0/nixos-root
  ```

- **Format home volume as ext4:**

  ```bash
  mkfs.ext4 -L nixos-home /dev/vg0/nixos-home
  ```

- **Format swap volume:**

  ```bash
  mkswap -L nixos-swap /dev/vg0/nixos-swap
  ```

### 4. Mount Partitions

**Mount Root Partition:**

```bash
mount /dev/vg0/nixos-root /mnt
```

**Create Necessary Directories on the Root Filesystem:**

```bash
mkdir -p /mnt/boot /mnt/home
```

**Mount Boot Partition:**

```bash
mount /dev/nvme0n1p2 /mnt/boot
```

**Create Directory for EFI System Partition and Mount It:**

```bash
mkdir -p /mnt/boot/efi
mount /dev/nvme0n1p1 /mnt/boot/efi
```

**Mount Home Partition (if separate):**

```bash
mount /dev/vg0/nixos-home /mnt/home
```

**Enable Swap:**

```bash
swapon /dev/vg0/nixos-swap
```

---

## 5. Generate NixOS Configuration and Install

1. **Generate the NixOS configuration:**
   ```sh
   nixos-generate-config --root /mnt
   ```

2. **Optionally, Download Your Configuration File:**

   If you don’t have your own configuration file, you can download mine for reference:
   ```sh
   curl -o /mnt/etc/nixos/configuration.nix https://raw.githubusercontent.com/titanknis/Nixos-Installation-Guide/main/configuration.nix
   ```

   **Note:** This file is customized for my setup. Common changes you might need to make include:
   - **Updating Partition UUIDs or Paths**
   - **Activating or Deactivating Services**
   - **Installing or Removing Applications**
   - **Configuring Desktop Environment** (if needed)

   For creating your own configuration, follow these steps:
   1. **Learn the Basics:** Begin with the [Nix.dev - Nix Language Tutorial](https://nix.dev/tutorials/nix-language.html) to understand the fundamentals of Nix.
   2. **Consult the Manual:** Read the relevant sections of the [NixOS Official Manual](https://nixos.org/manual/nixos/stable/) for information specific to your setup.
   3. **Refer to My Configuration File:** You can view [my configuration file](https://github.com/titanknis/Nixos-Installation-Guide/blob/main/configuration.nix). It’s thoroughly commented to guide you through the setup. Feel free to adapt it to suit your own needs.

   **Further Learning:**

   After you’ve settled in with NixOS and feel comfortable with the basics, consider exploring the [Nix Pills](https://nixos.org/guides/nix-pills/) series. These bite-sized tutorials can help you gradually deepen your understanding of Nix concepts. Don’t worry about tackling them right away—they’ll be there when you’re ready to learn more advanced topics.

   **Remember:** Mastering NixOS is a journey. Take your time to understand each concept thoroughly before moving on to more advanced topics.

3. **Change to the configuration directory and edit the configuration file using `vim` or nano or whatever your poison might be:**
   ```sh
   cd /mnt/etc/nixos
   vim configuration.nix
   ```

   Make necessary changes to match your setup.

4. **Install NixOS:**
   ```sh
   nixos-install
   ```

5. **Reboot the system:**
   ```sh
   reboot
   ```

---


## Troubleshooting

**In case of installation failure or if you need to fix a minor issue:**

1. **If partitions need to be recreated:**
   - Start from the [beginning of the guide](#nixos-installation-guide), including partitioning, formatting, and mounting. Refer to the [Partition the Disk Using `parted`](#2-partition-the-disk-using-parted), [Format Partitions](#3-format-partitions), and [Mount Partitions](#4-mount-partitions) sections for detailed instructions.

2. **If partitions are already present, properly formatted, and contain an almost fully functional system:**
   - **Open LUKS encrypted partitions:**
     ```sh
     cryptsetup open /dev/nvme0n1p3 luksCrypted
     ```

   - **Activate all LVM volume groups:**
     ```sh
     vgchange -ay
     ```
     **Note:** You will be prompted to enter the LUKS password.

   - **Mount partitions:**
     ```sh
     mount /dev/vg0/nixos-root /mnt
     mkdir -p /mnt/boot /mnt/home
     mount /dev/nvme0n1p2 /mnt/boot
     mkdir -p /mnt/boot/efi
     mount /dev/nvme0n1p1 /mnt/boot/efi
     mount /dev/vg0/nixos-home /mnt/home
     swapon /dev/vg0/nixos-swap
     ```

---
**The rest is up to you. Complete the installation or troubleshoot as needed based on your specific situation. Refer to the [Format Partitions](#3-format-partitions) and [Mount Partitions](#4-mount-partitions) sections as needed.
If issues persist or the system remains non-functional, consider reinstalling NixOS from the [beginning of the guide](#nixos-installation-guide).**

---

For more detailed information and additional help, consult the [NixOS Manual](https://nixos.org/manual/nixos/stable/).

---
