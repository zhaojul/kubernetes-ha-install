#!/bin/bash
. ./.env
echo ">>>>>> 安装 containerd <<<<<<"
for node_ip in ${NODE_IPS[@]}
 do
    while true
    do
      RETURN_NUM=`ssh root@${node_ip} 'systemctl status containerd.service > /dev/null; echo "$?"'`
        if [[ ${RETURN_NUM} = 0 ]]; then
          echo ">>> change: ${node_ip} install containerd done"
          break
        else
          echo ">>> change: ${node_ip} start install containerd"
          yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
          #scp -r ./config/containerd/docker-ce.repo root@${node_ip}:/etc/yum.repos.d/docker-ce.repo
          scp -r ./work/components/crictl/crictl root@${node_ip}:/usr/bin/crictl
          scp -r ./config/containerd/crictl.yaml root@${node_ip}:/etc/crictl.yaml
          ssh root@${node_ip} "systemctl disable --now docker.service; systemctl stop containerd.service; rm -rf /var/lib/docker; rm -rf /var/lib/containerd; rm -rf /etc/containerd"
          ssh root@${node_ip} "yum install -y yum-utils device-mapper-persistent-data lvm2 containerd.io; chmod 755 /usr/bin/crictl"
          ssh root@${node_ip} "mkdir -p /etc/containerd; containerd config default > /etc/containerd/config.toml;"
          ssh root@${node_ip} 'sed -i -e "s#SystemdCgroup = false#SystemdCgroup = true#" -e "s#k8s.gcr.io#docker.io/kubelibrary#" -e "s#registry.k8s.io#docker.io/kubelibrary#" /etc/containerd/config.toml;'
          ssh root@${node_ip} "systemctl daemon-reload; systemctl enable containerd.service --now;"
          sleep 5s
        fi
   done
done

echo ">>> containerd 安装完成 <<<"

