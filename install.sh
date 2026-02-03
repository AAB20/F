#!/bin/bash

# ==============================================================================
# ARCH LINUX INSTALLER: INTERNAL NVMe
# Desktop Environment: GNOME (Gnum) 🖥️
# User: abdullah | Pass: 2007
# Target: /dev/nvme0n1 (Internal MacBook SSD)
# Action: FORCE WIPE & INSTALL
# ==============================================================================

# إيقاف السكربت عند الأخطاء
set -e

DISK="/dev/nvme0n1"

echo "################################################################"
echo "##   INSTALLING ARCH LINUX WITH GNOME GUI                     ##"
echo "##   WARNING: ERASING INTERNAL MACBOOK DRIVE ($DISK)          ##"
echo "################################################################"
echo ">>> Starting in 10 seconds... Press Ctrl+C to CANCEL!"
sleep 10

# 1. التحقق من الإنترنت
echo ">>> [1/12] Checking Internet..."
ping -c 3 google.com > /dev/null 2>&1 || { echo "!!! No Internet."; exit 1; }

# 2. ضبط الوقت
timedatectl set-ntp true

# 3. المسح الإجباري (Fix Stuck Issue)
echo ">>> [2/12] Force wiping disk..."
umount -R /mnt 2>/dev/null || true
swapoff -a 2>/dev/null || true
# مسح مقدمة القرص لحذف أي تقسيمات ماك سابقة
dd if=/dev/zero of=$DISK bs=1M count=500 status=progress
partprobe $DISK
sleep 5

# 4. التقسيم (Partitioning)
echo ">>> [3/12] Creating Partitions..."
sgdisk -o $DISK
# EFI Partition (512MB)
sgdisk -n 1:0:+512M -t 1:ef00 $DISK
# Root Partition (Remaining)
sgdisk -n 2:0:0 -t 2:8300 $DISK

EFI_PART="${DISK}p1"
ROOT_PART="${DISK}p2"

partprobe $DISK
sleep 5

# 5. التهيئة (Formatting)
echo ">>> [4/12] Formatting..."
mkfs.fat -F32 -n EFI $EFI_PART
mkfs.ext4 -F -L ROOT $ROOT_PART

# 6. التركيب (Mounting)
echo ">>> [5/12] Mounting..."
mount $ROOT_PART /mnt
mkdir -p /mnt/boot
mount $EFI_PART /mnt/boot

# 7. تثبيت الحزم (GNOME + System)
echo ">>> [6/12] Installing GNOME Desktop & Base System..."
# تمت إضافة gnome-tweaks لتخصيص الواجهة
pacstrap /mnt base base-devel linux linux-firmware linux-headers \
    neovim networkmanager git sudo \
    intel-ucode broadcom-wl-dkms \
    mesa vulkan-intel intel-media-driver libva-intel-driver \
    sof-firmware alsa-utils lm_sensors xf86-input-libinput \
    python python-pip zsh \
    gnome gnome-extra gnome-tweaks gnome-software-packagekit-plugin firefox code --noconfirm

# 8. Fstab
genfstab -U /mnt >> /mnt/etc/fstab

# 9. إعداد النظام
echo ">>> [7/12] Configuring System..."

arch-chroot /mnt /bin/bash <<EOF

# الوقت واللغة (بغداد)
ln -sf /usr/share/zoneinfo/Asia/Baghdad /etc/localtime
hwclock --systohc
echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf
echo "arch-macbook" > /etc/hostname
echo "127.0.0.1 localhost" >> /etc/hosts

# المستخدم abdullah
useradd -m -G wheel -s /bin/zsh abdullah
echo "abdullah:2007" | chpasswd
echo "root:2007" | chpasswd

# Sudo مؤقت
echo "abdullah ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/temp_install

# Bootloader
bootctl --path=/boot install
echo "default arch.conf" > /boot/loader/loader.conf
echo "timeout 3" >> /boot/loader/loader.conf
echo "console-mode keep" >> /boot/loader/loader.conf 

UUID=\$(blkid -s UUID -o value $ROOT_PART)
cat <<ENTRY > /boot/loader/entries/arch.conf
title   Arch Linux (GNOME)
linux   /vmlinuz-linux
initrd  /intel-ucode.img
initrd  /initramfs-linux.img
options root=UUID=\$UUID rw quiet splash
ENTRY

# تفعيل واجهة GNOME (GDM)
systemctl enable NetworkManager
systemctl enable gdm
systemctl enable bluetooth

EOF

# 10. برامج AUR
echo ">>> [8/12] Installing AUR Apps..."
arch-chroot /mnt /bin/su - abdullah <<USERCMDS
    git config --global user.name "Abdullah Ali"
    git config --global init.defaultBranch main
    
    cd /tmp
    git clone https://aur.archlinux.org/yay.git
    cd yay
    makepkg -si --noconfirm
    
    # Chrome, Office, Telegram, Fan Control
    yay -S --noconfirm mbpfan-git google-chrome telegram-desktop-bin onlyoffice-bin
USERCMDS

# 11. النهاية
echo ">>> [9/12] Finalizing..."
arch-chroot /mnt /bin/bash <<EOF
    # إعداد المراوح
    [ -f /etc/mbpfan.conf.example ] && cp /etc/mbpfan.conf.example /etc/mbpfan.conf
    systemctl enable mbpfan
    
    # تنظيف Sudo
    rm /etc/sudoers.d/temp_install
    echo "%wheel ALL=(ALL:ALL) ALL" > /etc/sudoers.d/10-wheel
    chmod 640 /etc/sudoers.d/10-wheel
EOF

umount -R /mnt

echo "################################################################"
echo "##   INSTALLATION COMPLETE! (GNOME DESKTOP READY)             ##"
echo "################################################################"
echo "Type 'reboot' to start."
