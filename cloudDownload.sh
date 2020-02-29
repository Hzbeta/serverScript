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
    yum -y install findutils tar gzip dpkg curl wget ca-certificates
    bash <(curl -s -L git.io/ca-certificates.sh)
}

function make_dir() {
    mkdir -p "${download_dir}"
    mkdir -p "${cloud_download_config_dir}"
}

function install_aria2() {
    ARCH=$(uname -m)
    [ "$(command -v dpkg)" ] && dpkgARCH=$(dpkg --print-architecture | awk -F- '{ print $NF }')
    if [[ $ARCH == i*86 || $dpkgARCH == i*86 ]]; then
        ARCH="i386"
    elif [[ $ARCH == "x86_64" || $dpkgARCH == "amd64" ]]; then
        ARCH="amd64"
    elif [[ $ARCH == "aarch64" || $dpkgARCH == "arm64" ]]; then
        ARCH="arm64"
    elif [[ $ARCH == "armv7l" || $dpkgARCH == "armhf" ]]; then
        ARCH="armhf"
    else
        echo -e "不支持此 CPU 架构。"
        exit 1
    fi
    aria2_new_ver=$(wget -qO- https://api.github.com/repos/P3TERX/aria2-builder/releases | grep -o '"tag_name": ".*"' | head -n 1 | sed 's/"//g' | sed 's/tag_name: //g')
    [[ -z ${aria2_new_ver} ]] && echo -e "Aria2 最新版本获取失败，请手动获取最新版本号[ https://github.com/P3TERX/aria2-builder/releases ]" && exit 1
    wget -O- "https://github.com/P3TERX/aria2-builder/releases/download/${aria2_new_ver}/aria2-${aria2_new_ver}-static-linux-${ARCH}.tar.gz" | tar -zxC .
    [[ ! -s "aria2c" ]] && echo -e "$ Aria2 下载失败 !" && exit 1
    mv aria2c /usr/local/bin
    chmod +x /usr/local/bin/aria2c
    cat >"${cloud_download_config_dir}/aria2.conf" <<EOF
## RPC相关设置 ##

# 启用RPC, 默认:false
enable-rpc=true
# 接受所有远程请求, 默认:false
rpc-allow-origin-all=true
# 允许外部访问, 默认:false
rpc-listen-all=true
# 事件轮询方式, 取值:[epoll, kqueue, port, poll, select], 不同系统默认值不同
#event-poll=select
# RPC监听端口, 端口被占用时可以修改, 默认:6800
rpc-listen-port=${aria2_RPC_port}
# 设置的RPC授权令牌, v1.18.4新增功能, 取代 --rpc-user 和 --rpc-passwd 选项
rpc-secret=${password}
# 是否启用 RPC 服务的 SSL/TLS 加密,
# 启用加密后 RPC 服务需要使用 https 或者 wss 协议连接
#rpc-secure=true
# 在 RPC 服务中启用 SSL/TLS 加密时的证书文件(.pem/.crt)
#rpc-certificate=/config/xxx.pem
# 在 RPC 服务中启用 SSL/TLS 加密时的私钥文件(.key)
#rpc-private-key=/config/xxx.key

## 文件保存相关 ##

# 文件的保存路径(可使用绝对路径或相对路径), 默认: 当前启动位置
dir=${download_dir}
# 启用磁盘缓存, 0为禁用缓存, 需1.16以上版本, 默认:16M
# VPS 默认即可。本地路由器或 NAS 建议在有足够的内存空闲情况下设置为适当的大小，以减少磁盘 I/O 延长硬盘寿命。
#disk-cache=32M
# 文件预分配方式,, 默认:prealloc
# 预分配所需时间: none < falloc ? trunc < prealloc
# falloc和trunc则需要文件系统和内核支持，falloc 能有效降低磁盘碎片与内存占用
# NTFS(MinGW构建)、EXT4 建议使用 falloc, EXT3 建议 trunc, MAC 下需要注释此项。
# 若无法下载，提示 fallocate failed.cause：Operation not supported ，请设置为 none
file-allocation=falloc
# 断点续传
continue=true
# 获取服务器文件时间，默认:false
remote-time=true

## 下载连接相关 ##

# 文件未找到重试次数，默认:0
# 重试时同时会记录重试次数，所以也需要设置 --max-tries 这个选项
max-file-not-found=5
# 最大尝试次数，0表示无限，默认:5
max-tries=0
# 重试等待时间（秒）, 默认:0
retry-wait=10
# 使用 UTF-8 处理 Content-Disposition ，默认:false
content-disposition-default-utf8=true
# 最大同时下载任务数, 运行时可修改, 默认:5
max-concurrent-downloads=5
# 同一服务器连接数, 添加时可指定, 默认:1
max-connection-per-server=16
# 最小文件分片大小, 添加时可指定, 取值范围1M -1024M, 默认:20M
# 假定size=10M, 文件为20MiB 则使用两个来源下载; 文件为 15MiB 则使用一个来源下载
min-split-size=4M
# 单个任务最大线程数, 添加时可指定, 默认:5
split=16
# 整体下载速度限制, 运行时可修改, 默认:0
#max-overall-download-limit=0
# 单个任务下载速度限制, 默认:0
#max-download-limit=0
# 整体上传速度限制, 运行时可修改, 默认:0
max-overall-upload-limit=512K
# 单个任务上传速度限制, 默认:0
#max-upload-limit=1000
# 禁用IPv6, 默认:false
disable-ipv6=true
# 支持GZip，默认:false
http-accept-gzip=true
# URI复用，默认: true
reuse-uri=false
# 禁用 netrc 支持，默认:flase
no-netrc=true

## 进度保存相关 ##

# 从会话文件中读取下载任务
input-file=${cloud_download_config_dir}/aria2.session
# 在Aria2退出时保存错误与未完成的下载任务到会话文件
save-session=${cloud_download_config_dir}/aria2.session
# 定时保存会话, 0为退出时才保存, 需1.16.1以上版本, 默认:0
save-session-interval=1
# 自动保存任务进度，0为退出时才保存，默认：60
auto-save-interval=1
# 强制保存会话, 即使任务已经完成, 默认:false
# 较新的版本开启后会在任务完成后依然保留.aria2文件
#force-save=true

## BT/PT下载相关 ##

# 当下载的是一个种子(以.torrent结尾)时, 自动开始BT任务, 默认:true，可选：false|mem
#follow-torrent=true
# BT监听端口（TCP）, 默认:6881-6999
listen-port=6888
# 单个种子最大连接数，0为不限制，默认:55
bt-max-peers=0
# DHT（IPv4）文件
dht-file-path=${cloud_download_config_dir}/dht.dat
# DHT（IPv6）文件
dht-file-path6=${cloud_download_config_dir}/dht6.dat
# 打开DHT功能, PT需要禁用, 默认:true
enable-dht=true
# 打开IPv6 DHT功能, PT需要禁用
# 在没有 IPv6 的环境中不建议开启，否则会导致 DHT 功能异常。
enable-dht6=false
# DHT网络监听端口（UDP）, 默认:6881-6999
dht-listen-port=6888
# 本地节点查找, PT需要禁用, 默认:false
bt-enable-lpd=true
# 种子交换, PT需要禁用, 默认:true
enable-peer-exchange=true
# 期望下载速度，Aria2会临时提高连接数以提高下载速度，单位K或M。默认:50K
bt-request-peer-speed-limit=10M
# 当种子的分享率达到这个数时, 自动停止做种, 0为一直做种, 默认:1.0
seed-ratio=1.0
# 最小做种时间（分钟）。此选项设置为0时，将在BT任务下载完成后不进行做种。
seed-time=10
# BT校验相关, 默认:true
#bt-hash-check-seed=true
# 继续之前的BT任务时, 无需再次校验, 默认:false
#bt-seed-unverified=true
# 保存磁力链接元数据为种子文件(.torrent文件), 默认:false
bt-save-metadata=false
# 加载已保存的元数据文件，默认:false
bt-load-saved-metadata=true
# 删除未选择文件，默认:false
bt-remove-unselected-file=true
# 保存上传的种子，默认:true
#rpc-save-upload-metadata=false
# 客户端伪装
user-agent=Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_2) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/79.0.3945.117 Safari/537.36
# PT需要保持 user-agent 和 peer-agent 两个参数一致。即注释上面这行，然后取消注释下面的相关选项。
#user-agent=qBittorrent/4.2.1
peer-agent=qBittorrent/4.2.1
peer-id-prefix=-qB4210-
#----------------------------------
#user-agent=Transmission 2.94
#peer-agent=Transmission 2.94
#peer-id-prefix=-TR2940-
#----------------------------------
#user-agent=Deluge 2.0.3
#peer-agent=Deluge 2.0.3
#peer-id-prefix=-DE2030-
#----------------------------------
#user-agent=μTorrent 3.5.5
#peer-agent=μTorrent 3.5.5
#peer-id-prefix=-UT355W-
#----------------------------------
#user-agent=μTorrent Mac 1.8.7
#peer-agent=μTorrent Mac 1.8.7
#peer-id-prefix=-UM1870-

## BT加密设置（抗版权、防吸血） ##

# BT强制加密, 默认: false
# 启用后将拒绝旧的 BT 握手协议并仅使用混淆握手及加密，理论上可以防版权投诉与迅雷吸血。
# 此选项相当于后面两个选项(bt-require-crypto=true, bt-min-crypto-level=arc4)的快捷开启方式，但不会修改这两个选项的值。
bt-force-encryption=true
# BT加密需求，默认：false
# 启用后拒绝与旧的BitTorrent握手协议(\19BitTorrent protocol)建立连接，始终使用混淆处理握手。
#bt-require-crypto=true
# BT最低加密等级，可选：plain（明文），arc4（加密），默认：plain
#bt-min-crypto-level=arc4

## 执行额外命令 ##

# 下载停止后执行的命令（下载停止包含下载错误和下载完成这两个状态，如果没有单独设置，则执行此项命令。）
# 删除文件及.aria2后缀名文件
on-download-stop=${cloud_download_config_dir}/delete.sh
# 下载错误后执行的命令（下载停止包含下载错误这个状态，如果没被设置或被注释，则执行下载停止后执行的命令。）
#on-download-error=
# 下载完成后执行的命令（下载停止包含下载完成这个状态，如果没被设置或被注释，则执行下载停止后执行的命令。）
# 删除.aria2后缀名文件
on-download-complete=${cloud_download_config_dir}/delete.aria2.sh
# 调用 rclone 上传(move)到网盘
#on-download-complete=${cloud_download_config_dir}/autoupload.sh
# 下载暂停后执行的命令
# 显示下载任务信息
#on-download-pause=${cloud_download_config_dir}/info.sh
# 下载开始后执行的命令
#on-download-start=

## BT服务器 ##
bt-tracker=
EOF
    cat >"${cloud_download_config_dir}"/delete.aria2.sh <<"EOF"
#!/bin/bash
#=================================================================
# https://github.com/P3TERX/aria2.conf
# File name：delete.aria2.sh
# Description: Delete .aria2 file after Aria2 download is complete
# Lisence: MIT
# Version: 2.0
# Author: P3TERX
# Blog: https://p3terx.com
#=================================================================

DOWNLOAD_PATH='/data/downloads'

FILE_PATH=$3
REMOVE_DOWNLOAD_PATH=${FILE_PATH#${DOWNLOAD_PATH}/}
TOP_PATH=${DOWNLOAD_PATH}/${REMOVE_DOWNLOAD_PATH%%/*}
LIGHT_GREEN_FONT_PREFIX="\033[1;32m"
FONT_COLOR_SUFFIX="\033[0m"
INFO="[${LIGHT_GREEN_FONT_PREFIX}INFO${FONT_COLOR_SUFFIX}]"

echo -e "$(date +"%m/%d %H:%M:%S") ${INFO} Delete .aria2 file ..."

if [ $2 -eq 0 ]; then
    exit 0
elif [ -e "${FILE_PATH}.aria2" ]; then
    rm -vf "${FILE_PATH}.aria2"
elif [ -e "${TOP_PATH}.aria2" ]; then
    rm -vf "${TOP_PATH}.aria2"
fi
EOF
    cat >"${cloud_download_config_dir}"/delete.sh <<"EOF"
#!/bin/bash
#=====================================================
# https://github.com/P3TERX/aria2.conf
# File name：delete.sh
# Description: Delete files after Aria2 download error
# Lisence: MIT
# Version: 2.0
# Author: P3TERX
# Blog: https://p3terx.com
#=====================================================

DOWNLOAD_PATH='/data/downloads'

FILE_PATH=$3
REMOVE_DOWNLOAD_PATH=${FILE_PATH#${DOWNLOAD_PATH}/}
TOP_PATH=${DOWNLOAD_PATH}/${REMOVE_DOWNLOAD_PATH%%/*}
LIGHT_GREEN_FONT_PREFIX="\033[1;32m"
FONT_COLOR_SUFFIX="\033[0m"
INFO="[${LIGHT_GREEN_FONT_PREFIX}INFO${FONT_COLOR_SUFFIX}]"

echo -e "$(date +"%m/%d %H:%M:%S") ${INFO} Download error or stop, start deleting files..."

if [ $2 -eq 0 ]; then
    exit 0
elif [ -e "${FILE_PATH}.aria2" ]; then
    rm -vf "${FILE_PATH}.aria2" "${FILE_PATH}"
elif [ -e "${TOP_PATH}.aria2" ]; then
    rm -vrf "${TOP_PATH}.aria2" "${TOP_PATH}"
fi
find "${DOWNLOAD_PATH}" ! -path "${DOWNLOAD_PATH}" -depth -type d -empty -exec rm -vrf {} \;
EOF
    chmod +x "${cloud_download_config_dir}/delete.aria2.sh"
    chmod +x "${cloud_download_config_dir}/delete.sh"
    wget -P "${cloud_download_config_dir}" "https://raw.githubusercontent.com/P3TERX/aria2.conf/master/dht.dat"
    [[ ! -s "${cloud_download_config_dir}/dht.dat" ]] && echo -e "Aria2 DHT（IPv4）文件下载失败 !" && exit 1
    wget -P "${cloud_download_config_dir}" -N "https://raw.githubusercontent.com/P3TERX/aria2.conf/master/dht6.dat"
    [[ ! -s "${cloud_download_config_dir}/dht6.dat" ]] && echo -e "Aria2 DHT（IPv6）文件下载失败 !" && exit 1
    touch "${cloud_download_config_dir}/aria2.session"
    sed -i "s#^DOWNLOAD_PATH=.*#DOWNLOAD_PATH=\"${download_dir}\"#g" "${cloud_download_config_dir}/*.sh"
    bash <(curl -s -L git.io/tracker.sh) "${cloud_download_config_dir}/aria2.conf"
}

function install_filebrowser() {
    curl -fsSL https://filebrowser.xyz/get.sh | bash
    filebrowser -d "${cloud_download_config_dir}"/filebrowser.db config init --locale zh-cn
    filebrowser -d "${cloud_download_config_dir}"/filebrowser.db users add "${username}" "${password}" --perm.admin
    cat >"${cloud_download_config_dir}"/filebrowser.json <<EOF
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
    firewall-cmd --zone=public --add-port=51413/tcp --permanent
    firewall-cmd --zone=public --add-port=6881-6999/udp --permanent
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
Description=aria2
After=network.target
After=network-online.target

[Service]
Type=simple
ExecStart=/usr/local/bin/aria2c --conf-path=${cloud_download_config_dir}/aria2.conf
ExecStop=/etc/init.d/aria2 stop
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
make_dir
install_aria2
install_filebrowser
config_firewall
config_systemd

echo "FileBrowser http://your-ip:${filefrowser_port}"
echo "aria2 RPC http://your-ip:${aria2_RPC_port}/jsonrpc"
