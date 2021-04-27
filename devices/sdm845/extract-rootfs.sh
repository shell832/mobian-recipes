#!/bin/sh

IMAGE=$1

[ "$IMAGE" ] || exit 1

PART_OFFSET=`/sbin/fdisk -lu $IMAGE.img | tail -1 | awk '{ print $2; }'` &&
echo "Extracting rootfs @ $PART_OFFSET"
dd if=$IMAGE.img of=$IMAGE.root.img bs=512 skip=$PART_OFFSET
echo "Converting rootfs to sparse image"
img2simg $IMAGE.root.img $IMAGE.root.simg

BOOT_OFFSET=`/sbin/fdisk -lu $IMAGE.img | grep "\.img1" | awk '{ print $3; }'` &&
BOOT_SIZE=`/sbin/fdisk -lu $IMAGE.img | grep "\.img1" | awk '{ print $5; }'` &&
echo "Extracting boot @ $BOOT_OFFSET length $BOOT_SIZE"
dd if=$IMAGE.img of=$IMAGE.boot.img bs=512 skip=$BOOT_OFFSET count=$BOOT_SIZE
# The boot partition on oneplus6 is a bit more than 64M
truncate -s 64M $IMAGE.boot.img
