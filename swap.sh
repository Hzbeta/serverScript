#!/usr/bin/env bash

[[ $EUID -ne 0 ]] && echo "[Error] This script must be run as root" && exit 1
[[ -d "/proc/vz" ]] && echo -e "OpenVZ is not supported!" && exit 1

if [ -z "${1}" ]; then
    echo -e "Usage: ${0} size(MB)"
fi

swapsize=${1}

if grep -q "swapfile" /etc/fstab; then
    sed -i '/swapfile/d' /etc/fstab
    echo "3" >/proc/sys/vm/drop_caches
    swapoff -a
    rm -f /swapfile
fi
fallocate -l "${swapsize}"M /swapfile
chmod 600 /swapfile
mkswap /swapfile
swapon /swapfile
echo '/swapfile none swap defaults 0 0' >>/etc/fstab
cat /proc/swaps
grep </proc/meminfo Swap
free -h
