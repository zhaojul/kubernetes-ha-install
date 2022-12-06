#!/bin/bash
. ./.env
. ./.version

echo ">>>>>>正在安装网络组件<<<<<<"

CALICO () {
sed \
    -e 's@# - name: CALICO_IPV4POOL_CIDR@- name: CALICO_IPV4POOL_CIDR@g' \
    -e 's@#   value: "192.168.0.0/16"@  value: '\"${KUBE_POD_CIDR}\"'@g' \
    ./network/calico/calico.yaml | tee ./work/calico.yaml
kubectl --kubeconfig=./work/pki/admin.conf apply -f ./work/calico.yaml
}

CANAL () {
sed \
    -e 's@canal_iface: ""@canal_iface: '\"${KUBE_NETWORK_IFACE}\"'@g' \
    -e 's@"Network": "10.244.0.0/16"@"Network": '\"${KUBE_POD_CIDR}\"'@g' \
    -e 's@# - name: CALICO_IPV4POOL_CIDR@- name: CALICO_IPV4POOL_CIDR@g' \
    -e 's@#   value: "192.168.0.0/16"@  value: '\"${KUBE_POD_CIDR}\"'@g' \
    ./network/canal/canal.yaml | tee ./work/canal.yaml
kubectl --kubeconfig=./work/pki/admin.conf apply -f ./work/canal.yaml
}

FLANNEL () {
sed \
    -e 's@"Network": "10.244.0.0/16"@"Network": '\"${KUBE_POD_CIDR}\"'@g' \
    ./network/flannel/kube-flannel.yaml | tee ./work/kube-flannel.yaml
kubectl --kubeconfig=./work/pki/admin.conf apply -f ./work/kube-flannel.yaml
}


if [ "${KUBE_NETWORK_PLUGIN}" = "calico" ]; then
CALICO
elif [ "${KUBE_NETWORK_PLUGIN}" = "canal" ]; then
CANAL
elif [ "${KUBE_NETWORK_PLUGIN}" = "flannel" ]; then
FLANNEL
fi

echo ">>>检查网络组件安装:"
while true
do
    kubectl --kubeconfig=./work/pki/admin.conf get node | grep 'NotReady' > /dev/null
    if [[ ! $? = 0 ]]; then
        sleep 10s;
        echo ">>>Pods启动状态:"
        kubectl --kubeconfig=./work/pki/admin.conf get pods -n kube-system -o wide
        echo ">>>Node就绪状态:"
        kubectl --kubeconfig=./work/pki/admin.conf get node -o wide
        break
    fi
done


