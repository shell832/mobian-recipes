#!/bin/sh

DEVICE="$1"
DTB_DEVICE="enchilada"

# Force update the initramfs so we create an up-to-date bootimg
update-initramfs -u -k all

sed -i '/\/boot/d' /etc/fstab

ROOTPART=$(grep f2fs /etc/fstab | awk '{print $1;}')
BOOTDEV=$(lsblk -o PATH,MOUNTPOINT -n | grep /boot | awk '{ print $1; }')
KERNEL_VERSION=$(linux-version list)

case "$DEVICE" in
    "oneplus6t")
        DTB_DEVICE="fajita"
        ;;
    "pocof1")
        DTB_DEVICE="beryllium"
        ;;
esac

# Append DTB to kernel
cat /boot/vmlinuz-$KERNEL_VERSION /usr/lib/linux-image-$KERNEL_VERSION/qcom/sdm845-oneplus-$DTB_DEVICE.dtb > /tmp/kernel-dtb

mkbootimg --kernel /tmp/kernel-dtb --ramdisk /boot/initrd.img-$KERNEL_VERSION \
    --kernel_offset 0x8000 --ramdisk_offset 0x1000000 --tags_offset 0x100 \
    --pagesize 4096 --cmdline "mobian.root=$ROOTPART init=/sbin/init rw quiet splash" \
    --base 0x0 --second_offset 0x0 -o /tmp/bootimg

umount /boot
dd if=/tmp/bootimg of=$BOOTDEV bs=1M
