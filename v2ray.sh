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

if [[ -z "${1}" || -z "${2}" ]]; then
    echo -e "Usage: ${0} uuid port"
    exit 0
fi

export uuid=${1}
export port=${2}
v2ray_config="/usr/local/etc/v2ray/config.json"

yum install -y curl
bash <(curl -L https://raw.githubusercontent.com/v2fly/fhs-install-v2ray/master/install-release.sh)

cat >${v2ray_config} <<EOF
{
  "inbounds": [
    {
      "listen": "0.0.0.0",
      "port": "${port}",
      "protocol": "vmess",
      "settings": {
        "clients": [
          {
            "id": "${uuid}",
            "level": 1,
            "alterId": 64
          }
        ]
      },
      "streamSettings": {
        "network": "tcp",
        "tcpSettings": {
          "header": {
            "type": "http",
            "response": {
              "version": "1.1",
              "status": "200",
              "reason": "OK",
              "headers": {
                "Content-Type": [
                  "application/octet-stream",
                  "video/mpeg"
                ],
                "Transfer-Encoding": [
                  "chunked"
                ],
                "Connection": [
                  "keep-alive"
                ],
                "Pragma": "no-cache"
              }
            }
          }
        }
      }
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom",
      "settings": {}
    },
    {
      "protocol": "blackhole",
      "settings": {},
      "tag": "blocked"
    }
  ],
  "routing": {
    "domainStrategy": "IPOnDemand",
    "rules": [
      {
        "type": "field",
        "outboundTag": "adblock",
        "domain": [
          "geosite:category-ads"
        ]
      }
    ]
  }
}
EOF

firewall-cmd --permanent --zone=public --add-port="${port}"/tcp
firewall-cmd --reload

systemctl enable v2ray
systemctl start v2ray
