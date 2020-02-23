#!/bin/bash
function Check_is_Root_in_CentOS8() {
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

function deal_args() {
    if [[ -z "${1}" ]]; then
        echo -e "Usage: ${0} username password [filefrowser_port] [aria2_RPC_port] [cloud_download_config_dir] [download_dir]"
        echo -r "default filefrowser_port : 1003"
        echo -e "default aria2_RPC_port : 6800"
        echo -e "default cloud_download_config_dir : /etc/cloud_download"
        echo -e "default download_dir : /data/downloads"
        exit 0
    fi
    username=${1}
    password=${2}
    if [ -z "${3}" ]; then
        filefrowser_port=1003
    else
        filefrowser_port=${3}
    fi
    if [ -z "${4}" ]; then
        aria2_RPC_port=6800
    else
        aria2_RPC_port=${4}
    fi
    if [ -z "${5}" ]; then
        cloud_download_config_dir="/etc/cloud_download"
    else
        cloud_download_config_dir=${5}
    fi
    if [ -z "${6}" ]; then
        download_dir="/data/downloads"
    else
        download_dir=${6}
    fi
}

function install_dep() {
    yum -y install podman curl
}

function config_file() {
    mkdir -p "${download_dir}"
    mkdir -p "${cloud_download_config_dir}"
}

function install_aria2() {
    podman create -d \
        --name aria2 \
        --log-opt max-size=1m \
        -p "${aria2_RPC_port}":6800 \
        -e PUID="${UID}" \
        -e PGID="${GID}" \
        -e RPC_SECRET="${password}" \
        -v "${cloud_download_config_dir}":/config \
        -v "${download_dir}":/downloads \
        p3terx/aria2-pro
}

function install_filebrowser() {
    curl -fsSL https://filebrowser.xyz/get.sh | bash
    filebrowser -d "${cloud_download_config_dir}"/filebrowser.db config init --locale zh-cn
    filebrowser -d "${cloud_download_config_dir}"/filebrowser.db users add "${username}" "${password}" --perm.admin
    cat >"${cloud_download_config_dir}"/filebrowser.json <<-EOF
{
    "port": ${filefrowser_port},
    "baseURL": "",
    "address": "0.0.0.0",
    "log": "stdout",
    "database": "${cloud_download_config_dir}/filebrowser.db",
    "root": "${download_dir}"
}
EOF
}

function config_firewall() {
    firewall-cmd --zone=public --add-port="${filefrowser_port}"/tcp --permanent
    firewall-cmd --zone=public --add-port="${aria2_RPC_port}"/tcp --permanent
    firewall-cmd --zone=public --add-port=6888/tcp --permanent
    firewall-cmd --zone=public --add-port=6888/udp --permanent
    firewall-cmd --reload
}

function config_systemd() {
    cat >/usr/lib/systemd/system/filebrowser.service <<EOF
[Unit]
Description=Filebrowser Service
After=network.target
Wants=network.target

[Service]
Type=simple
PIDFile=/var/run/filebrowser.pid
ExecStart=/usr/local/bin/filebrowser -c ${cloud_download_config_dir}/filebrowser.json
RestartSec=10s
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF
    cat >/usr/lib/systemd/system/aria2.service <<EOF
[Unit]
Description=podman aria2
After=network.target
After=network-online.target

[Service]
Type=simple
ExecStart=/usr/bin/podman start -a aria2
ExecStop=/usr/bin/podman stop aria2
RestartSec=10s
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

    systemctl enable aria2
    systemctl enable filebrowser
    systemctl start aria2
    systemctl start filebrowser

}

Check_is_Root_in_CentOS8
deal_args "$@"
install_dep
config_file
install_aria2
install_filebrowser
config_firewall
config_systemd

echo "FileBrowser http://your-ip:${filefrowser_port}"
echo "aria2 RPC http://your ip:${aria2_RPC_port}/jsonrpc"
