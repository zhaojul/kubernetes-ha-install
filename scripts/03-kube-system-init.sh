#!/bin/bash
. ./.env
rm -rf ./work/hosts
touch ./work/hosts
echo "127.0.0.1   localhost localhost.localdomain localhost4 localhost4.localdomain4" > ./work/hosts
echo "::1         localhost localhost.localdomain localhost6 localhost6.localdomain6" >> ./work/hosts
echo "${HAPROXY_IP}  ${HAPROXY_NAME}" >> ./work/hosts

i=0
for ip in ${MASTER_IPS[@]}
do
let i++
  echo "${ip}  `echo ${MASTER_NAMES[@]} | cut -d " " -f $i`" >> ./work/hosts
done

i=0
for ip in ${NODE_IPS[@]}
do
let i++
  echo "${ip}  `echo ${NODE_NAMES[@]} | cut -d " " -f $i`" >> ./work/hosts
done

cp -r /etc/hosts /etc/hosts-default-backup 
cp -r ./work/hosts /etc/hosts
cp -r ./work/components/cfssl* /usr/bin/
cp -r ./work/components/kubernetes/server/bin/kubeadm /usr/bin/kubeadm
cp -r ./work/components/kubernetes/server/bin/kubectl /usr/bin/kubectl
cp -r ./work/components/helm/linux-amd64/helm /usr/bin/helm
chmod +x /usr/bin/cfssl* /usr/bin/{kubeadm,kubectl,helm}

if [ ! -f ~/.ssh/id_rsa ]; then
echo ">>>>>> 设置ssh免密登陆 <<<<<<"
yum -y install sshpass jq openssl openssh telnet
ssh-keygen -t rsa -P "" -C "Kubernetes-Setup-Tools" -f ~/.ssh/id_rsa
fi
for node in ${HAPROXY_IP} ${MASTER_IPS[@]} ${NODE_IPS[@]};
do
  echo ">>>${node}";
  sshpass -p ${ROOT_PWD} ssh-copy-id -o stricthostkeychecking=no root@${node}
done

echo ">>>>>> 正在为所有节点安装基础的依赖包并修改配置,这需要较长的一段时间 <<<<<<"
i=0
for node in ${HAPROXY_IP} ${MASTER_IPS[@]} ${NODE_IPS[@]};
do
  let i++
  echo ">>>>>>>> ${node} 节点环境准备中 <<<<<<";
  ssh -o stricthostkeychecking=no root@${node} "cp -r /etc/hosts /etc/hosts.back"
  scp -r ./work/hosts root@${node}:/etc/hosts
  ssh root@${node} "hostnamectl set-hostname `echo ${HAPROXY_NAME} ${MASTER_NAMES[@]} ${NODE_NAMES[@]} | cut -d " " -f $i`"
  ssh root@${node} "systemctl stop firewalld; systemctl disable firewalld; systemctl stop dnsmasq; systemctl disable dnsmasq; systemctl stop ntpd; systemctl disable ntpd; systemctl stop postfix; systemctl disable postfix;"
  ssh root@${node} "iptables -F && iptables -X && iptables -F -t nat && iptables -X -t nat && iptables -P FORWARD ACCEPT"
  ssh root@${node} "swapoff -a; sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab; setenforce 0"
  ssh root@${node} "sed -i '/SELINUX/s/enforcing/disabled/' /etc/selinux/config"
  ssh root@${node} "yum -y install epel-release; yum -y install yum-utils chrony curl wget vim sysstat net-tools openssl openssh lsof socat nfs-utils cifs-utils; systemctl disable rpcbind;"
  ssh root@${node} "timedatectl set-timezone Asia/Shanghai; timedatectl set-local-rtc 0; systemctl restart chronyd; systemctl enable chronyd; systemctl restart rsyslog; systemctl restart crond"
  ssh root@${node} "cp /etc/sysctl.conf /etc/sysctl.conf.back; echo > /etc/sysctl.conf; sysctl -p"
  scp -r ./config/kernel/kubernetes.conf root@${node}:/etc/sysctl.d/kubernetes.conf
done

echo ">>>>>> 升级系统内核,内核版本为${Kernel_Version} <<<<<<"
for node in ${HAPROXY_IP} ${MASTER_IPS[@]} ${NODE_IPS[@]};
do 
  echo ">>> ${node} 升级内核中"
  ssh root@${node} "mkdir /tmp/kernel-update/"
  scp -r ./work/components/kernel-lt* root@${node}:/tmp/kernel-update/
  ssh root@${node} "cd /tmp/kernel-update/; yum install kernel-lt-*.rpm -y; sleep 3s; rm -rf /tmp/kernel-update;"
  ssh root@${node} "grub2-set-default  0 && grub2-mkconfig -o /etc/grub2.cfg; sleep 5s; grubby --default-kernel; sleep 5s; reboot;"
done

for node in ${HAPROXY_IP} ${MASTER_IPS[@]} ${NODE_IPS[@]};
 do            
    while true
    do 
      ping -c 4 -w 100  ${node} > /dev/null 
       if [[ $? = 0 ]];then  
          echo " ${node} 主机 ping ok,开始下一步安装"
          echo ">>>>>> ${node} 节点安装基础依赖包并配置内核模块 <<<<<<";
          ssh root@${node} "yum install -y conntrack ipvsadm ipset iptables sysstat libseccomp"
          scp -r ./config/modules-load/ipvs.conf root@${node}:/tmp/ipvs.conf
          scp -r ./config/modules-load/containerd.conf root@${node}:/tmp/containerd.conf
          ssh root@${node} "cat /tmp/ipvs.conf > /etc/modules-load.d/ipvs.conf; rm -rf /tmp/ipvs.conf; cat /tmp/containerd.conf > /etc/modules-load.d/containerd.conf; rm -rf /tmp/containerd.conf; systemctl enable --now systemd-modules-load.service; lsmod |egrep 'ip_vs*|nf_conntrack|br_netfilter|overlay'; sysctl -p /etc/sysctl.d/kubernetes.conf;"
          sleep 3s
          ssh root@${node} "reboot"
          echo ">>>>>>>>>> ${node} install ok <<<<<<<<<"
          break
        else                   
          echo " ${node} 主机还未reboot成功,请稍后... "
          sleep 5s
        fi
   done
done

for node in ${HAPROXY_IP} ${MASTER_IPS[@]} ${NODE_IPS[@]};
 do
    while true
    do
      ping -c 4 -w 100  ${node} > /dev/null
        if [[ $? = 0 ]];then
          echo " ${node} 节点 ping ok"
          break
        else
          echo " ${node} 节点还未reboot成功,请稍后... "
          sleep 5s
        fi
   done
done

echo ">>>>>> 导入kube-control-plane需要的环境变量 <<<<<<"
for node in ${MASTER_IPS[@]};
do
cat > ./work/kube-control-plane-${node} <<EOF
NODE_IP="${node}"
ETCD_ENDPOINTS="https://${MASTER_IPS[0]}:2379,https://${MASTER_IPS[1]}:2379,https://${MASTER_IPS[2]}:2379"
NODE_PORT_RANGE="3000-32767"
KUBE_SERVICE_CIDR="${KUBE_SERVICE_CIDR}"
KUBE_POD_CIDR="${KUBE_POD_CIDR}"
EOF
scp -r ./work/kube-control-plane-${node} root@${node}:/etc/sysconfig/kube-control-plane
done


echo ">>>>>> 导入kube-node需要的环境变量 <<<<<<"

if [ ${MASTER_IS_WORKER} = true ]; then
i=o
for node in ${MASTER_IPS[@]};
do
cat > ./work/kube-node-${node} <<EOF
NODE_NAME="${MASTER_NAMES[i]}"
KUBE_POD_CIDR="${KUBE_POD_CIDR}"
EOF
scp -r ./work/kube-node-${node} root@${node}:/etc/sysconfig/kube-node
let i++
done
fi

i=o
for node in ${NODE_IPS[@]};
do
cat > ./work/kube-node-${node} <<EOF
NODE_NAME="${NODE_NAMES[i]}"
KUBE_POD_CIDR="${KUBE_POD_CIDR}"
EOF
scp -r ./work/kube-node-${node} root@${node}:/etc/sysconfig/kube-node
let i++
done


