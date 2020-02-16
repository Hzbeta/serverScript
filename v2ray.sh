#!/bin/bash

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

if [[ -z "${1}" || -z "${2}" ]]; then
    echo -e "Usage: ${0} uuid port [kcp|ws]"
    exit 0
fi

if [ -n "${3}" ]; then
    case "${3}" in
    "kcp")
        jqStr='.inbounds[0]+={"streamSettings":{"network":"mkcp","kcpSettings":{"header":{"type":"utp"}}}}'
        ;;
    "ws")
        jqStr='.inbounds[0]+={"streamSettings":{"network":"ws"}}'
        ;;
    *)
        echo -e "Usage: ${0} uuid port [kcp|ws]"
        exit 0
        ;;
    esac
fi


uuid=${1}
port=${2}

bash <(curl -s -L https://install.direct/go.sh)

sed -i "s/\(\"port\"\s*:\)\s*[[:digit:]]\+/\1 ${port}/g" /etc/v2ray/config.json
sed -i "s/\(\"id\"\s*:\)\s*\".*\"/\1 \"${uuid}\"/g" /etc/v2ray/config.json

if [ -n "${jqStr}" ]; then
    yum -y install jq
    mv /etc/v2ray/config.json /etc/v2ray/config.bak
    jq "${jqStr}" /etc/v2ray/config.bak >/etc/v2ray/config.json
fi

firewall-cmd --permanent --zone=public --add-port="${port}"/tcp
firewall-cmd --reload

systemctl start v2ray
