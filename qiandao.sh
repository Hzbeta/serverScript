#!/bin/bash
#only for centos 8
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

if [ -z "${1}" ]; then
    echo -e "Usage: ${0} port"
fi

port=${1}

yum install podman -y

podman create -d -p "${port}":80 --name qiandao fangzhengjin/qiandao

cat>/usr/lib/systemd/system/qiandao.service<<EOF
[Unit]
Description=podman qiandao server
After=network.target
After=network-online.target

[Service]
Type=simple
ExecStart=/usr/bin/podman start -a qiandao
ExecStop=/usr/bin/podman stop qiandao
RestartSec=10s
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

firewall-cmd --permanent --zone=public --add-port "${port}"/tcp
podman0=$(nmcli con show | grep -P "^.*?podman\d" -o)
firewall-cmd --zone=trusted --add-interface="${podman0}"
firewall-cmd --reload

systemctl enable qiandao
systemctl start qiandao

echo "done!"