# nixos installation guide

---

### NixOS Installation Guide

**Summary:**
This guide will walk you through installing NixOS, covering connecting to WiFi, partitioning the disk, formatting and mounting partitions, and completing the installation. Follow these steps to set up an encrypted root filesystem with dedicated boot, home, and swap volumes.
---

**1. Connect to WiFi:**

1. **Start `wpa_supplicant`:**
   ```sh
   sudo systemctl start wpa_supplicant
   ```

2. **Configure WiFi with `wpa_cli`:**
   ```sh
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

**Correct Mounting Order Summary**

Here's the recommended mounting order to ensure all directories are properly placed on the root filesystem:

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

**Key Points:**

- **Directories Creation:** Ensures that `/mnt/boot/efi` and `/mnt/home` are available on the root filesystem before mounting the partitions.
- **ESP Accessibility:** Mounting the ESP first ensures that it is correctly accessible even if other partitions are unmounted.
- **Boot Partition:** Mounted after the ESP to prevent it from obscuring the `/boot/efi` mount point.
- **Home Partition:** Mounted last to keep user data separate and organized.

This order maintains a clear and functional directory structure and prevents potential issues with directory visibility or mount conflicts.

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

4. **Pull the trigger!**  
   Once you’re satisfied with your configuration, pull the trigger and proceed with the installation.

5. **Install NixOS:**
   ```sh
   nixos-install
   ```

6. **Reboot the system:**
   ```sh
   reboot
   ```

---

**Final Words:**

Congratulations on setting up NixOS! If you encounter any issues or need further customization, the NixOS community and documentation are excellent resources. Enjoy your new system!

---
