#!/bin/bash
. ./.env
echo ">>>>>> 安装 docker <<<<<<"
for node_ip in ${NODE_IPS[@]}
 do
    while true
    do
      RETURN_NUM=`ssh root@${node_ip} 'systemctl status docker.service > /dev/null; echo "$?"'`
        if [[ ${RETURN_NUM} = 0 ]]; then
          echo ">>> change: ${node_ip} install docker done"
          break
        else
          echo ">>> change: ${node_ip} start install docker"
          ssh root@${node_ip} "mkdir -p /etc/docker; systemctl stop docker.service; rm -rf /var/lib/docker;"
          scp -r ./config/docker/docker-ce.repo root@${node_ip}:/etc/yum.repos.d/docker-ce.repo
          scp -r ./config/docker/daemon.json root@${node_ip}:/etc/docker/daemon.json
          ssh root@${node_ip} "yum install -y yum-utils device-mapper-persistent-data lvm2; yum -y install docker-ce docker-ce-cli;"
          ssh root@${node_ip} "systemctl daemon-reload; systemctl enable docker.service --now;"
          sleep 5s
        fi
   done
done

echo ">>> docker安装完成 <<<"

