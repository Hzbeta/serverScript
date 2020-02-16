#!/bin/bash

Check_is_Root_in_CentOS8() {
    if grep -Eqi "CentOS" /etc/issue || grep -Eq "CentOS" /etc/*-release; then
        DISTRO='CentOS'
    elif grep -Eqi "Debian" /etc/issue || grep -Eq "Debian" /etc/*-release; then
        DISTRO='Debian'
    elif grep -Eqi "Ubuntu" /etc/issue || grep -Eq "Ubuntu" /etc/*-release; then
        DISTRO='Ubuntu'
    elif grep -Eqi "Raspbian" /etc/issue || grep -Eq "Raspbian" /etc/*-release; then
        DISTRO='Raspbian'
    else
        DISTRO='unknow'
    fi
    [[ $EUID -ne 0 ]] && echo "[Error] This script must be run as root" && exit 1
    if [ "$DISTRO" != "CentOS" ]; then
        echo "[Error] This script can only run in CentOS"
        exit 1
    fi
    (rpm -q centos-release | grep 'release\-8') >/dev/null || (echo "[Error] This script can only run in CentOS 8" && exit 1)
}

Check_is_Root_in_CentOS8

if [[ -z "${1}" || -z "${2}" ]]; then
    echo -e "Usage: ${0} port aria2_RPC_SECRET"
    exit 0
fi

port=${1}
RPC_SECRET=${2}

yum install -y podman

podman run -d --name cloud-download \
    -p "${port}":80 \
    -e RPC_SECRET="${RPC_SECRET}" \
    wahyd4/aria2-ui

firewall-cmd --permanent --zone=public --add-port="${port}"/tcp
firewall-cmd --reload

echo "FileBrowser http://ip:${port}"
echo "aria2 http://ip:${port}/ui"