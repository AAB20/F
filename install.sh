#!/bin/bash

# ==============================================================================
# ARCH LINUX INSTALLER: INTERNAL MACBOOK DRIVE (NVMe)
# Target: /dev/nvme0n1 (Internal SSD)
# User: abdullah | Pass: 2007
# Desktop: GNOME | Apps: Chrome, VS Code, Office, Telegram
# Action: DESTROY MACOS -> INSTALL ARCH LINUX
# ==============================================================================

# إيقاف السكربت عند حدوث أي خطأ
set -e

# تحديد القرص الداخلي
DISK="/dev/nvme0n1"

echo "################################################################"
echo "##   DANGER! DANGER! DANGER!                                  ##"
echo "##   YOU ARE ABOUT TO ERASE THE INTERNAL MACBOOK DRIVE!       ##"
echo "##   MACOS WILL BE DELETED PERMANENTLY!                       ##"
echo "################################################################"
echo ">>> ستبدأ العملية خلال 10 ثوانٍ... اضغط Ctrl+C للإلغاء الآن!"
sleep 10

# 1. التحقق من الإنترنت
echo ">>> [1/11] التحقق من الإنترنت..."
ping -c 3 google.com > /dev/null 2>&1 || { echo "!!! خطأ: لا يوجد إنترنت. صل هاتفك."; exit 1; }

# 2. ضبط الوقت
timedatectl set-ntp true

# 3. تنظيف الهارد الداخلي (Wiping)
echo ">>> [2/11] تنظيف الهارد الداخلي..."
umount -R /mnt 2>/dev/null || true
swapoff -a 2>/dev/null || true

echo ">>> [3/11] جاري مسح القرص $DISK..."
# مسح التواقيع القديمة
wipefs --all --force $DISK
# مسح جدول الأقسام بالكامل
sgdisk --zap-all $DISK
partprobe $DISK
sleep 3

# 4. التقسيم (NVMe Partitioning)
echo ">>> [4/11] إنشاء الأقسام..."
# قسم EFI بحجم 512 ميجا
sgdisk -n 1:0:+512M -t 1:ef00 $DISK
# قسم Root بباقي المساحة
sgdisk -n 2:0:0 -t 2:8300 $DISK

# ملاحظة هامة: أقراص NVMe تأخذ اللاحقة p1, p2
EFI_PART="${DISK}p1"
ROOT_PART="${DISK}p2"

sleep 3

# 5. التهيئة (Formatting)
echo ">>> [5/11] تهيئة الأقسام..."
mkfs.fat -F32 -n EFI $EFI_PART
mkfs.ext4 -F -L ROOT $ROOT_PART

# 6. التركيب (Mounting)
echo ">>> [6/11] التركيب..."
mount $ROOT_PART /mnt
mkdir -p /mnt/boot
mount $EFI_PART /mnt/boot

# 7. تثبيت الحزم (Pacstrap)
echo ">>> [7/11] تنزيل النظام والبرامج (يرجى الانتظار)..."
# Drivers: Intel GPU + Audio + Broadcom WiFi
# Apps: GNOME + VS Code + Python + Firefox
pacstrap /mnt base base-devel linux linux-firmware linux-headers \
    neovim networkmanager git sudo \
    intel-ucode broadcom-wl-dkms \
    mesa vulkan-intel intel-media-driver libva-intel-driver \
    sof-firmware alsa-utils lm_sensors xf86-input-libinput \
    python python-pip zsh \
    gnome gnome-extra gnome-software-packagekit-plugin firefox code --noconfirm

# 8. إنشاء ملف fstab
genfstab -U /mnt >> /mnt/etc/fstab

# 9. إعداد النظام الداخلي
echo ">>> [8/11] إعداد النظام والمستخدم..."

arch-chroot /mnt /bin/bash <<EOF

# إعداد الوقت واللغة (بغداد)
ln -sf /usr/share/zoneinfo/Asia/Baghdad /etc/localtime
hwclock --systohc
echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf
echo "arch-macbook" > /etc/hostname
echo "127.0.0.1 localhost" >> /etc/hosts

# إنشاء المستخدم abdullah
useradd -m -G wheel -s /bin/zsh abdullah
echo "abdullah:2007" | chpasswd
echo "root:2007" | chpasswd

# صلاحيات Sudo مؤقتة
echo "abdullah ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/temp_install

# تثبيت Bootloader (Systemd-boot)
bootctl --path=/boot install
echo "default arch.conf" > /boot/loader/loader.conf
echo "timeout 3" >> /boot/loader/loader.conf
echo "console-mode keep" >> /boot/loader/loader.conf 

# جلب UUID للقرص
UUID=\$(blkid -s UUID -o value $ROOT_PART)

cat <<ENTRY > /boot/loader/entries/arch.conf
title   Arch Linux
linux   /vmlinuz-linux
initrd  /intel-ucode.img
initrd  /initramfs-linux.img
options root=UUID=\$UUID rw quiet splash
ENTRY

# تفعيل الخدمات
systemctl enable NetworkManager
systemctl enable gdm
systemctl enable bluetooth

EOF

# 10. تثبيت برامج AUR (Chrome, Office, etc)
echo ">>> [9/11] تثبيت برامج AUR (قد يأخذ وقتاً)..."
echo ">>> رجاءً لا تغلق الجهاز..."

arch-chroot /mnt /bin/su - abdullah <<USERCMDS
    # إعداد Git
    git config --global user.name "Abdullah Ali"
    git config --global init.defaultBranch main

    # تثبيت yay
    cd /tmp
    git clone https://aur.archlinux.org/yay.git
    cd yay
    makepkg -si --noconfirm

    # تثبيت البرامج
    # mbpfan-git: تحكم بالمراوح
    yay -S --noconfirm mbpfan-git google-chrome telegram-desktop-bin onlyoffice-bin
USERCMDS

# 11. النهاية
echo ">>> [10/11] اللمسات الأخيرة..."
arch-chroot /mnt /bin/bash <<EOF
    # إعداد ملف المراوح
    [ -f /etc/mbpfan.conf.example ] && cp /etc/mbpfan.conf.example /etc/mbpfan.conf
    systemctl enable mbpfan
    
    # استعادة أمان Sudo
    rm /etc/sudoers.d/temp_install
    echo "%wheel ALL=(ALL:ALL) ALL" > /etc/sudoers.d/10-wheel
    chmod 640 /etc/sudoers.d/10-wheel
EOF

umount -R /mnt

echo "################################################################"
echo "##   INSTALLATION COMPLETE!                                   ##"
echo "##   MACOS IS GONE. WELCOME TO ARCH LINUX.                    ##"
echo "################################################################"
echo "اكتب 'reboot' الآن لإعادة التشغيل."
