#!/bin/sh

export PATH=/sbin:/usr/sbin:$PATH
DEBOS_CMD=debos
if [ -z ${ARGS+x} ]; then
    ARGS=""
fi

device="pinephone"
image="image"
partitiontable="mbr"
filesystem="f2fs"
environment="phosh"
nonfree="false"
arch="arm64"
family="sunxi"
do_compress=
image_only=
imagesize="3.8GB"
installer=
zram=
memory=
password=
use_docker=
username=
no_blockmap=
ssh=
debian_suite="bookworm"
suite="bookworm"
contrib=
sign=
miniramfs=

while getopts "dDizobsc:e:f:g:h:m:p:t:u:F:S:" opt
do
  case "$opt" in
    d ) use_docker=1 ;;
    D ) debug=1 ;;
    e ) environment="$OPTARG" ;;
    H ) hostname="$OPTARG" ;;
    i ) image_only=1 ;;
    z ) do_compress=1 ;;
    b ) no_blockmap=1 ;;
    s ) ssh=1 ;;
    o ) installer=1 ;;
    c ) cpus="$OPTARG" ;;
    f ) ftp_proxy="$OPTARG" ;;
    h ) http_proxy="$OPTARG" ;;
    g ) sign="$OPTARG" ;;
    m ) memory="$OPTARG" ;;
    p ) password="$OPTARG" ;;
    t ) device="$OPTARG" ;;
    u ) username="$OPTARG" ;;
    F ) filesystem="$OPTARG" ;;
    x ) debian_suite="$OPTARG" ;;
    S ) suite="$OPTARG" ;;
    C ) contrib=1 ;;
    r ) miniramfs=1 ;;
  esac
done

case "$device" in
  "pinephone" )
    ;;
  "pinetab" )
    ;;
  "librem5" )
    family="librem5"
    ;;
  "oneplus6"|"pocof1" )
    arch="arm64"
    family="sdm845"
    suite="unstable"
    ARGS="$ARGS -t nonfree:true -t imagesize:5GB"
    ;;
  "a5ulte" )
    arch="arm64"
    family="msm8916"
    ARGS="$ARGS -t nonfree:true -t imagesize:5GB"
    ;;
  "surfacepro3" )
    arch="amd64"
    family="amd64"
    partitiontable="gpt"
    nonfree="true"
    imagesize="5GB"
    ;;
  "amd64" )
    arch="amd64"
    family="amd64"
    device="efi"
    partitiontable="gpt"
    imagesize="20GB"
    ;;
  "amd64-legacy" )
    arch="amd64"
    family="amd64"
    device="pc"
    imagesize="20GB"
    ;;
  * )
    echo "Unsupported device '$device'"
    exit 1
    ;;
esac

if [ "$installer" ]; then
  image="installer"
  image_file="mobian-installer-$device-$environment-`date +%Y%m%d`.img"
else
  image_file="mobian-$device-$environment-`date +%Y%m%d`.img"
fi

if [ "$use_docker" ]; then
  DEBOS_CMD=docker
  ARGS="run --rm --interactive --tty --device /dev/kvm --workdir /recipes \
            --mount type=bind,source=$(pwd),destination=/recipes \
            --security-opt label=disable godebos/debos"
fi
if [ "$debug" ]; then
  ARGS="$ARGS --debug-shell"
fi

if [ "$username" ]; then
  ARGS="$ARGS -t username:$username"
fi

if [ "$password" ]; then
  ARGS="$ARGS -t password:$password"
fi

if [ "$ssh" ]; then
  ARGS="$ARGS -t ssh:$ssh"
fi

if [ "$environment" ]; then
  ARGS="$ARGS -t environment:$environment"
fi

if [ "$http_proxy" ]; then
  ARGS="$ARGS -e http_proxy:$http_proxy"
fi

if [ "$ftp_proxy" ]; then
  ARGS="$ARGS -e ftp_proxy:$ftp_proxy"
fi

if [ "$memory" ]; then
  ARGS="$ARGS --memory=$memory"
fi

if [ "$cpus" ]; then
  ARGS="$ARGS --cpus=$cpus"
fi

ARGS="$ARGS -t architecture:$arch -t family:$family -t device:$device -t nonfree:$nonfree \
            -t partitiontable:$partitiontable -t filesystem:$filesystem -t imagesize:$imagesize\
            -t environment:$environment -t image:$image_file \
            -t debian_suite:$debian_suite -t suite:$suite --scratchsize=8G"

if [ ! "$image_only" -o ! -f "$rootfs_file" ]; then
  $DEBOS_CMD $ARGS rootfs.yaml || exit 1
  if [ "$installer" ]; then
    $DEBOS_CMD $ARGS installfs.yaml || exit 1
  fi
fi

if [ ! "$image_only" -o ! -f "rootfs-$device-$environment.tar.gz" ]; then
  $DEBOS_CMD $ARGS "rootfs-device.yaml" || exit 1
fi

# Convert rootfs tarball to squashfs for inclusion in the installer image
if [ "$installer" -a ! -f "rootfs-$device-$environment.sqfs" ]; then
  zcat "rootfs-$device-$environment.tar.gz" | tar2sqfs "rootfs-$device-$environment.sqfs"
fi

$DEBOS_CMD $ARGS "$image.yaml"

if [ ! "$no_blockmap" -a -f "$image_file.img" ]; then
  bmaptool create "$image_file.img" > "$image_file.img.bmap"
fi

if [ "$do_compress" ]; then
  echo "Compressing ${image_file}..."
  [ -f ${image_file}.img ] && gzip --keep --force ${image_file}.img
  [ -f ${image_file}.root.img ] && tar czf ${image_file}.tar.gz ${image_file}.boot-*.img ${image_file}.root.img
fi

if [ -n "$sign" ]; then
    truncate -s0 ${image_file}.sha256sums
    if [ "$do_compress" ]; then
        extensions="img.gz tar.gz img.bmap"
    else
        extensions="img boot-*.img root.img img.bmap"
    fi

    for ext in ${extensions}; do
        for file in $(ls ${image_file}.${ext} 2>/dev/null); do
            sha256sum ${file} >> ${image_file}.sha256sums
        done
    done

    [ -f ${image_file}.sha256sums.asc ] && rm ${image_file}.sha256sums.asc
    gpg -u ${sign} --clearsign ${image_file}.sha256sums
fi
