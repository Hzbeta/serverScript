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
    echo -e "Usage: ${0} clustertoken [ServerModCollectionID]"
fi

clustertoken=${1}
if [ -n "${2}" ]; then
    ServerModCollectionID=${2}
fi

useradd dstserver
su - dstserver -c "wget -O linuxgsm.sh https://linuxgsm.sh && chmod +x linuxgsm.sh && bash linuxgsm.sh dstserver"
bash /home/dstserver/dstserver auto-install
su - dstserver -c "bash /home/dstserver/dstserver auto-install"
su - dstserver -c "mkdir -p /home/dstserver/.klei/DoNotStarveTogether/Cluster_1"
su - dstserver -c "echo ${clustertoken}>/home/dstserver/.klei/DoNotStarveTogether/Cluster_1/cluster_token.txt"

#issue https://github.com/GameServerManagers/LinuxGSM/issues/2660
cat >/home/dstserver/lgsm/config-lgsm/dstserver/dstserver.cfg <<"EOF"
clustercfgdir="${persistentstorageroot}/${confdir}/${cluster}"
servercfgdir="${clustercfgdir}/${shard}"
servercfgfullpath="${servercfgdir}/${servercfg}"
clustercfgfullpath="${clustercfgdir}/${clustercfg}"
EOF

if [ -n "${ServerModCollectionID}" ]; then
    su - dstserver -c "echo ServerModCollectionSetup\(\"${ServerModCollectionID}\"\)>>/home/dstserver/serverfiles/mods/dedicated_server_mods_setup.lua"
fi

#limit cpu
yum install -y libcgroup libcgroup-tools
echo """
group dstserver {
    cpu {
        cpu.cfs_quota_us=75000;
    }
}
""" >>/etc/cgconfig.conf
systemctl enable cgconfig
systemctl start cgconfig

{
    echo "alias dststart='cgexec -g cpu:dstserver su - dstserver -c \"~/dstserver start\"'"
    echo "alias dststop='su - dstserver -c \"~/dstserver stop\"'"
    echo "alias dstinfo='su - dstserver -c \"~/dstserver dt\"'"
} >>~/.bashrc

echo """
Useage
start : cgexec -g cpu:dstserver su - dstserver -c \"~/dstserver start\"
stop : su - dstserver -c \"~/dstserver stop\"
info : su - dstserver -c \"~/dstserver dt\"
view log: tail -f /home/dstserver/.klei/DoNotStarveTogether/Cluster_1/Master/server_log.txt
"""
