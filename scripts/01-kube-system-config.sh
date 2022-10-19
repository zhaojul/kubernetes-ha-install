#!/bin/bash
clear
echo "---------------------------------"
echo "k8s安装配置向导"
echo "此向导需要配置以下内容:"
echo "---------------------------------"
echo " * 集群信息,包括部门信息、环境信息、节点池信息; 此项设置为自动生成主机名并配置为Kubernetes节点的名称; 输入IP的过程请务必仔细！ "
echo " * Kubernetes所需Master集群的IP地址信息,需要三个IP地址(仅支持3节点的Master集群,其他节点数量暂时不支持);"
echo " * HAproxy节点地址,不能是Kubernete任何节点IP,需要地址不被占用;"
echo " * Kubernetes集群网路类型,默认flannel,可选canal或calico;"
echo " * 请确保master节点和node节点的root密码相同."
echo "------------------------------------------------------------------------------------------------------------------"
echo ""
while true
do
   read -r -p "是否继续? [Y/N] " ACCEPT
   case ${ACCEPT} in
       [yY][eE][sS]|[yY])
       echo "You chose to continue";
       break;
       ;;
       [nN][oO]|[nN])
       echo -e "\033[31mCancel\033[0m";
       exit 1;
       ;;
       *)
       echo -e "\033[31mInvalid Input\033[0m";
       ;;
  esac
done

NODEPOOLID=`cat /dev/urandom | head -n 20 | cksum | head -c 8`

READPAR1 () {
read -p "请输入集群名称(默认Kubernetes), 仅支持小写英文输入: " CLUSTERNAME
CLUSTERNAME=${CLUSTERNAME}
[ ! "${CLUSTERNAME}x" == "x" ] || CLUSTERNAME="Kubernetes"
read -p "请输入节点池名称(默认default), 仅支持小写英文输入: " NODEPOOLNAME
NODEPOOLNAME=${NODEPOOLNAME}
[ ! "${NODEPOOLNAME}x" == "x" ] || NODEPOOLNAME="default"
}

READPAR2 () {
read -p "请输入HAproxy节点IP地址,该地址会被作为Control Plane Endpoint: " vip
HAPROXY_IP="${vip}"
HAPROXY_NAME="k8s-${NODEPOOLNAME}-masterpool-${NODEPOOLID}-loadbalance"

read -p "请输入MASTER节点地址,三个IP之间以空格隔开: " masterip
K8S_M1=`echo ${masterip} |cut -d " " -f 1`
K8S_M2=`echo ${masterip} |cut -d " " -f 2`
K8S_M3=`echo ${masterip} |cut -d " " -f 3`
MASTER_IPS=( ${masterip} )
if [ "${K8S_M1}x" == "x" ] || [ "${K8S_M2}x" == "x" ] || [ "${K8S_M3}x" == "x" ] || [ "${HAPROXY_IP}x" == "x" ]; then
   echo "您输入了空值,请重新输入"
   READPAR2
fi
}

READPAR3 () {
read -p "请输入NODE节点地址,多个IP中间以空格隔开: " nodeip
NODE_IPS=( ${nodeip} )
if [ "${nodeip}x" == "x" ]; then
    echo "您输入了空值,请重新输入"
    READPAR3
fi
}

READPAR4 () {
read -p "请输入节点的root密码(请确保master节点和node节点的root密码相同): " rootpwd
ROOT_PWD=${rootpwd}
if [ "${rootpwd}x" == "x" ]; then
    echo "您输入了空值,请重新输入"
    READPAR4
else
echo "你输入的密码为 ${rootpwd}"
fi
}

READPAR5 () {
echo "
网段选择: pod 和 service 的网段不能与服务器网段重叠，
示例参考：
    * 如果服务器网段为: 10.0.0.0/8
        pod 网段可设置为: 172.20.0.0/16
        service 网段可设置为 172.21.0.0/16
    * 如果服务器网段为: 172.16.0.0/12
        pod 网段可设置为: 10.244.0.0/16
        service 网段可设置为 10.96.0.0/16
    * 如果服务器网段为: 192.168.0.0/16
        pod 网段可设置为: 10.244.0.0/16
        service 网段可设置为 10.96.0.0/16
"
read -p "请输入Pod网络CIDR(默认10.244.0.0/16): " podcidr
KUBE_POD_CIDR=${podcidr}
[ ! "${podcidr}x" == "x" ] || KUBE_POD_CIDR="10.244.0.0/16";
read -p "请输入Service网络CIDR(默认10.96.0.0/16): " servicecidr
KUBE_SERVICE_CIDR=${servicecidr}
[ ! "${servicecidr}x" == "x" ] || KUBE_SERVICE_CIDR="10.96.0.0/16";
KUBE_SERVICE_IP="`echo ${KUBE_SERVICE_CIDR} | awk -F. '{print $1 "." $2 "." $3}'`.1"
KUBE_DNS_SVC_IP="`echo ${KUBE_SERVICE_CIDR} | awk -F. '{print $1 "." $2 "." $3}'`.10"
}

READPAR6 () {
while true
do
echo "
选择Kubernetes集群网络组件类型, 默认安装Flannel网络组件.
Flannel (default)    [1], 
Canal                [2],
Calico               [3],
";
read -r TYPE
if [ "x${TYPE}" = "x" ] || [ "x${TYPE}" = "x1" ]; then
    echo "你选择了安装Flannel,安装工具会自动安装该网络组件";
    KUBE_NETWORK_PLUGIN="flannel"
    break;
elif [ "x${TYPE}" = "x2" ]; then
    echo "你选择了安装Canal,安装工具会自动安装该网络组件";
    KUBE_NETWORK_PLUGIN="canal"
    break;
elif [ "x${TYPE}" = "x3" ]; then
    echo "你选择了安装Calico,安装工具会自动安装该网络组件";
    KUBE_NETWORK_PLUGIN="calico"
    break;
else
   echo -e "\033[31mInvalid Input\033[0m";
fi
done
}


MASTERHOSTNAME () {
i=0
for ip in ${MASTER_IPS[@]}
do
let i++
  echo "k8s-${NODEPOOLNAME}-masterpool-${NODEPOOLID}-${i}"
  echo 
done
}

CHECKHAPROXY () {
echo "HAproxy节点IP:                        ${HAPROXY_IP}"
echo "HAproxy节点Hostname:                  ${HAPROXY_NAME}"
echo "Kubernetes Control Plane Endpoint:    https://${HAPROXY_IP}:6443"
}

CHECKMASTER () {
c=0
for line in `MASTERHOSTNAME`
do
    mastername[${c}]=$line
    let c=${c}+1
done

MASTER_NAMES=`echo ${mastername[@]}`
echo "MASTER节点IP:                         ${MASTER_IPS[@]}"
echo "MASTER节点Hostname:                   ${MASTER_NAMES}"
}

NODEHOSTNAME () {
i=0
for ip in ${NODE_IPS[@]}
do
let i++
  echo "k8s-${NODEPOOLNAME}-agentpool-${NODEPOOLID}-${i}"
done
}

CHECKNODE () {
c=0
for line in `NODEHOSTNAME`
do
    nodename[${c}]=${line}
    let c=${c}+1
done

NODE_NAMES=`echo ${nodename[@]}`
echo "NODE节点IP:                           ${NODE_IPS[@]}"
echo "NODE节点Hostname:                     ${NODE_NAMES}"
}


CONFIG () {
READPAR1
READPAR2
READPAR3
READPAR4
READPAR5
READPAR6
}

CONFIG

while true
do
    echo ""
    echo "---------------------------------------------------------------------------"
    echo "* Below is all the information you entered:"
    echo "* Kubernetes Name:                        ${CLUSTERNAME}"
    echo "* Kubernetes Control Plane Endpoint:      https://${HAPROXY_IP}:6443"
    echo "* kubernetes Master IPs:                  ${masterip}"
    echo "* Kubernetes Node IPs:                    ${nodeip}"
    echo "* Kubernetes Nodes root password:         ${ROOT_PWD}"
    echo "* Kubernetes Nodepool Name:               ${NODEPOOLNAME}"
    echo "* Kubernetes podCIDR:                     ${KUBE_POD_CIDR}"
    echo "* Kubernetes serviceCIDR:                 ${KUBE_SERVICE_CIDR}"
    echo "* Kubernetes Network Plugin:              ${KUBE_NETWORK_PLUGIN}"
    echo "---------------------------------------------------------------------------"
    read -r -p "确定请输入[Y], 重新输入[N]: " ACCEPT
    case ${ACCEPT} in
        [yY][eE][sS]|[yY])
        echo "You chose to continue";
        break;
        ;;
        [nN][oO]|[nN])
        CONFIG
        ;;
        *)
        echo -e "\033[31mInvalid Input\033[0m";
        ;;
    esac
done

CHECKHAPROXY
CHECKMASTER
CHECKNODE

cat > ./.env <<EOF
CLUSTERNAME="${CLUSTERNAME}"
NODEPOOLNAME="${NODEPOOLNAME}"
NODEPOOLID="${NODEPOOLID}"
HAPROXY_NAME="${HAPROXY_NAME}"
HAPROXY_IP="${HAPROXY_IP}"
MASTER_NAMES=( ${MASTER_NAMES} )
MASTER_IPS=( ${masterip} )
NODE_NAMES=( ${NODE_NAMES} )
NODE_IPS=( ${nodeip} )
ROOT_PWD="$ROOT_PWD"

KUBE_NETWORK_IFACE="eth0"
KUBE_NETWORK_PLUGIN="${KUBE_NETWORK_PLUGIN}"
KUBE_SERVICE_IP="${KUBE_SERVICE_IP}"
KUBE_SERVICE_CIDR="${KUBE_SERVICE_CIDR}"
KUBE_POD_CIDR="${KUBE_POD_CIDR}"
KUBE_DNS_SVC_IP="${KUBE_DNS_SVC_IP}"
KUBE_DNS_DOMAIN="cluster.local"

KUBE_VERSION="v1.22.15"
ETCD_VERSION="v3.5.5"
COREDNS_VERSION="v1.8.4"
CNI_PLUGINS_VERSION="v1.1.1"
CRICTL_VERSION="v1.22.1"
KERNEL_VERSION="5.4.134-1"
CFSSL_VERSION="1.6.1"
HELM_VERSION="v3.8.2"
POD_INFRA_CONTAINER_IMAGE="docker.io/kubelibrary/pause:3.5"

EOF

