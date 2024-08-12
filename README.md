# NixOS Installation Guide

**Table of Contents:**

1. [Connect to WiFi](#1-connect-to-wifi)
2. [Partition the Disk Using `parted`](#2-partition-the-disk-using-parted)
3. [Format Partitions](#3-format-partitions)
4. [Mount Partitions](#4-mount-partitions)
5. [Generate NixOS Configuration and Install](#5-generate-nixos-configuration-and-install)
6. [Troubleshooting](#troubleshooting)

---

# 1. Connect to WiFi:

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

**2. Partition the Disk Using `parted`:**

1. **Start `parted` in interactive mode:**
   ```sh
   parted /dev/nvme0n1
   ```

2. **Create partitions with labels:**
   - **Create the ESP partition (1 MiB to 1 GiB) as FAT32:**
     ```sh
     (parted) mkpart ESP fat32 1MiB 1GiB
     (parted) set 1 esp on
     ```

   - **Create the BOOT partition (1 GiB to 2 GiB) as ext4:**
     ```sh
     (parted) mkpart BOOT ext4 1GiB 2GiB
     ```

   - **Create the LUKS encrypted partition (2 GiB to end - 1 MiB):**
     ```sh
     (parted) mkpart LUKS 2GiB -1MiB
     ```

3. **Print the partition table to verify:**
   ```sh
   (parted) print
   ```

---

**3. Format Partitions:**

1. **Format the ESP partition (1 MiB to 1 GiB) as FAT32:**
   ```sh
   mkfs.fat -F32 -n ESP /dev/nvme0n1p1  # Format ESP partition
   ```

2. **Format the BOOT partition (1 GiB to 2 GiB) as ext4:**
   ```sh
   mkfs.ext4 -L nixos-boot /dev/nvme0n1p2  # Format boot partition
   ```

3. **Initialize the LUKS encrypted partition (2 GiB to end - 1 MiB):**
   ```sh
   cryptsetup luksFormat /dev/nvme0n1p3  # Initialize LUKS encryption
   ```

   **Open the LUKS partition:**
   ```sh
   cryptsetup open /dev/nvme0n1p3 luksCrypted  # Open LUKS partition
   ```

4. **Create LVM physical volume on the decrypted partition:**
   ```sh
   pvcreate /dev/mapper/luksCrypted  # Create LVM physical volume
   ```

5. **Create an LVM volume group (e.g., `vg0`):**
   ```sh
   vgcreate vg0 /dev/mapper/luksCrypted  # Create LVM volume group
   ```

6. **Create logical volumes in the following order:**
   - **Create root volume (30 GiB):**
     ```sh
     lvcreate -L 30G -n nixos-root vg0  # Create root logical volume
     ```

   - **Create home volume (50 GiB):**
     ```sh
     lvcreate -L 50G -n nixos-home vg0  # Create home logical volume
     ```

   - **Create swap volume (20 GiB):**
     ```sh
     lvcreate -L 20G -n nixos-swap vg0  # Create swap logical volume
     ```

7. **Format logical volumes:**
   - **Format root volume as ext4:**
     ```sh
     mkfs.ext4 -L nixos-root /dev/vg0/nixos-root  # Format root logical volume
     ```

   - **Format home volume as ext4:**
     ```sh
     mkfs.ext4 -L nixos-home /dev/vg0/nixos-home  # Format home logical volume
     ```

   - **Format swap volume:**
     ```sh
     mkswap -L nixos-swap /dev/vg0/nixos-swap  # Format swap logical volume
     ```

---

**4. Mount Partitions:**

1. **Mount Root Partition:**
   ```sh
   mount /dev/vg0/nixos-root /mnt  # Mount root logical volume
   ```

2. **Create Necessary Directories on the Root Filesystem:**
   ```sh
   mkdir -p /mnt/boot/efi /mnt/home  # Create boot and home directories
   ```

3. **Mount EFI System Partition (ESP):**
   ```sh
   mount /dev/nvme0n1p1 /mnt/boot/efi  # Mount ESP partition
   ```

4. **Mount Boot Partition:**
   ```sh
   mount /dev/nvme0n1p2 /mnt/boot  # Mount boot partition
   ```

5. **Mount Home Partition (if separate):**
   ```sh
   mount /dev/vg0/nixos-home /mnt/home  # Mount home logical volume
   ```

6. **Enable Swap:**
   ```sh
   swapon /dev/vg0/nixos-swap  # Enable swap logical volume
   ```

---

**5. Generate NixOS Configuration and Install:**

1. **Generate the NixOS configuration:**
   ```sh
   nixos-generate-config --root /mnt
   ```

2. **Optionally, pull the configuration repository from GitHub and force overwrite:**
   ```sh
   git clone https://github.com/titanknis/nixos.git /mnt/etc/nixos --force
   ```

3. **Change to the configuration directory and edit the configuration file using `vim`:**
   ```sh
   cd /mnt/etc/nixos
   vim configuration.nix
   ```

4. **Install NixOS:**
   ```sh
   nixos-install
   ```

5. **Reboot the system:**
   ```sh
   reboot
   ```

---

**Troubleshooting:**

**In case of installation failure or if you need to fix a minor issue:**

1. **If partitions need to be recreated, start from the beginning of the guide.**  
   This includes creating the partition table, partitioning, formatting, and mounting. Refer to the [NixOS Installation Guide](#nixos-installation-guide) for detailed instructions.

2. **Optionally, format the partitions if you need to correct their filesystems.**  
   Refer to the [Formatting Partitions](#3-format-partitions) section of the guide for specific commands.

3. **If partitions are already present and you need to fix a minor issue:**

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
     mkdir -p /mnt/boot/efi /mnt/home
     mount /dev/nvme0n1p1 /mnt/boot/efi
     mount /dev/nvme0n1p2 /mnt/boot
     mount /dev/vg0/nixos-home /mnt/home
     swapon /dev/vg0/nixos-swap
     ```

**The rest is up to you. Complete the installation or troubleshoot as needed based on your specific situation. Refer to the [Formatting Partitions](#3-format-partitions) and [Mount Partitions](#4-mount-partitions) sections as needed.**

---

For more detailed information and additional help, consult the [NixOS Manual](https://nixos.org/manual/nixos/stable/).

---
