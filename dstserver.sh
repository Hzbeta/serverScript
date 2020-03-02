#!/usr/bin/env bash

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
cat>/home/dstserver/lgsm/config-lgsm/dstserver/dstserver.cfg<<"EOF"
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
systemctl enable cgconfig
echo """
group dstserver {
    cpu {
        cpu.cfs_quota_us=75000;
    }
}
""">>/etc/cgconfig.conf
systemctl restart cgconfig

echo """
Useage
start : cgexec -g cpu:dstserver su - dstserver -c \"~/dstserver start\"
stop : su - dstserver -c \"~/dstserver stop\"
view log: tail -f /home/dstserver/.klei/DoNotStarveTogether/Cluster_1/Master/server_log.txt
"""