#!/usr/bin/env bash

Check_is_Root_in_CentOS() {
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
    (rpm -q centos-release | grep 'release\-6') >/dev/null && (echo "[Error] This script can only run in CentOS 7+" && exit 1)
}

Check_is_Root_in_CentOS

if [ -z "${1}" ]; then
    echo -e "Usage: ${0} CustumPort"
    exit 0
fi

port=$1

sed -i "s/#Port 22/Port ${port}/" /etc/ssh/sshd_config
semanage port -a -t ssh_port_t -p tcp "${port}"
firewall-cmd --permanent --zone=public --add-port="${port}"/tcp
firewall-cmd --reload
systemctl restart sshd.service

echo -e 'Done!'
