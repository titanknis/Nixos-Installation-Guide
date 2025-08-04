# NixOS Installation Guide

**Table of Contents:**

1. [Preface](#preface)
2. [Preparations](#preparations)
   - [Installation Media](#installation-media)
   - [System Configuration](#system-configuration)
3. [Installation Process](#installation-process)
   - [Change keyboard layout](#change-keyboard-layout)
   - [Connect to WiFi](#connect-to-wifi)
   - [Partition the Disk Using `parted`](#partition-the-disk-using-parted)
   - [Format Partitions](#format-partitions)
   - [Mount Partitions](#mount-partitions)
   - [Generate NixOS Configuration and Install](#generate-nixos-configuration-and-install)

---

## Preface

**Requirements for this guide:**

- **LVM disk partitioning** for flexibility in storage management.
- **LUKS encryption** for the entire LVM physical volume for security.
- **UEFI boot loader** and **boot partition**.
- **Unencrypted boot partition** to allow the bootloader to access its files.
- **USB stick installation**.
- **Connecting to the internet using WiFi** (specifically WPA) instead of Ethernet.
- **Full disk installation only**; no dual boot.

**Expected Outcome:**
By following this guide, you will have a secure NixOS system with encrypted storage and LVM management, tailored to your specific hardware and preferences.

**Important:** All commands should be executed as the root user. To gain root access, use:

```sh
sudo -i
```

**Note:** For the most part, installing NixOS is straightforward if you follow this guide. However, a basic understanding of the Nix language is essential. NixOS is deeply integrated with Nix, and you'll need to learn it to create your own configuration or modify an existing one to suit your preferences.

I won’t be covering Nix language fundamentals in this guide. If you have a basic understanding, my example configuration file should be clear and helpful. Learning the basics of Nix is not difficult—it’s quite accessible and easy to grasp. For an introduction, you can refer to the [Nix Language Tutorial](https://nix.dev/tutorials/nix-language.html "The official Nix language basics").

---

## Preparations

### Installation Media

1. **Download the 64-bit minimal install CD** from the [NixOS downloads page](https://nixos.org/download.html "Obviously the official download page").

2. **Verify the ISO Integrity**
   - Download the SHA256 checksum file from the same page.
   - Place both the ISO and checksum file in the same folder.
   - Run:

     ```sh
     sha256sum -c <checksum-file>
     ```

   - Ensure the output indicates that the ISO file is `OK`. If the verification fails, redownload the ISO and checksum files and repeat the verification process.

3. **Create a Bootable USB Stick**
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

### System Configuration

Some UEFI system settings need to be adjusted for NixOS installation. To find the exact steps for your machine, do a quick web search for your model. For example, on my HP, you press `F12` at boot to access the UEFI menu.

Once in the menu:

1. **Ensure Safe Boot is Disabled**.
2. **Ensure Fast Boot is Disabled**.
3. **Ensure UEFI Mode is Enabled**.
4. **Ensure Boot from USB is Enabled**.

---

## Installation Process

### Change keyboard layout

**Note:** I will be using `colemak-dh`. You can choose other layouts, like `fr` or `de`.

The **US layout** is chosen by default.

```sh
sudo loadkeys mod-dh-ansi-us
```

For other layouts like French or German:

- **French**: `sudo loadkeys fr`
- **German**: `sudo loadkeys de`

### Connect to WiFi

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

### Partition the Disk Using `parted`

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

   - **Create the LUKS encrypted partition (1 GiB to end - 1 MiB):**

     ```sh
     (parted) mkpart LUKS 1GiB -1MiB
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

### Format Partitions

**Format the ESP partition (1 MiB to 1 GiB) as FAT32:**

```bash
mkfs.fat -F32 -n ESP /dev/nvme0n1p1
```

**Initialize the LUKS encrypted partition (1 GiB to end - 1 MiB):**

```bash
cryptsetup luksFormat /dev/nvme0n1p2
```

**Open the LUKS partition:**

```bash
cryptsetup open /dev/nvme0n1p2 luksCrypted
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

- **Create root volume (50 GiB, adjust based on your requirements):**

  ```bash
  lvcreate -L 50G -n nixos-root vg0
  ```

- **Create home volume (80 GiB, adjust based on your requirements):**

  ```bash
  lvcreate -L 80G -n nixos-home vg0
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

---

### Mount Partitions

**Mount Root Partition:**

```bash
mount /dev/vg0/nixos-root /mnt
```

**Create Necessary Directories on the Root Filesystem:**

```bash
mkdir /mnt/boot /mnt/home
```

**Mount Boot Partition:**

```bash
mount /dev/nvme0n1p1 /mnt/boot
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

### 5. Generate NixOS Configuration and Install

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
   1. **Learn the Basics:** Begin with the [Nix Language Tutorial](https://nix.dev/tutorials/nix-language.html "Nix.dev official Nix language basics") to understand the fundamentals of Nix.
   2. **Consult the Manual:** Read the relevant sections of the [NixOS Official Manual](https://nixos.org/manual/nixos/stable/ "The official NixOS Manual for the stable channel") for information specific to your setup.
   3. **Refer to My Configuration File:** You can view [my configuration file](https://github.com/titanknis/Nixos-Installation-Guide/blob/main/configuration.nix "I hope you find this as helpful as I found others' configs. Take whatever you need from it."). It’s thoroughly commented to guide you through the setup. Feel free to adapt it to suit your own needs.

   **Further Learning:**

   After you’ve settled in with NixOS and feel comfortable with the basics, consider exploring the [Nix Pills](https://nixos.org/guides/nix-pills/ "The Nix Pills are considered a classic introduction to Nix") series. These bite-sized tutorials can help you gradually deepen your understanding of Nix concepts. Don’t worry about tackling them right away—they’ll be there when you’re ready to learn more advanced topics.

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
