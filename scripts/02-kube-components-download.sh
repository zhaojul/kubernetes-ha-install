#!/bin/bash
. ./.env
. ./.version
rm -rf ./work
mkdir -p ./work/components
cd ./work/components

DOWNLOAD () {
curl -LO http://storage.corpintra.plus/kubernetes/release/${KUBE_VERSION}/kubernetes-server-linux-amd64.tar.gz
curl -LO http://storage.corpintra.plus/etcd/etcd-${ETCD_VERSION}-linux-amd64.tar.gz
curl -LO http://storage.corpintra.plus/cni/cni-plugins-linux-amd64-${CNI_PLUGINS_VERSION}.tgz
curl -LO http://storage.corpintra.plus/crictl/crictl-${CRICTL_VERSION}-linux-amd64.tar.gz
curl -LO http://storage.corpintra.plus/helm/helm-${HELM_VERSION}-linux-amd64.tar.gz
curl -LO http://storage.corpintra.plus/elrepo/kernel/kernel-lt-${KERNEL_VERSION}.el7.elrepo.x86_64.rpm
curl -LO http://storage.corpintra.plus/elrepo/kernel/kernel-lt-devel-${KERNEL_VERSION}.el7.elrepo.x86_64.rpm
curl -LO http://storage.corpintra.plus/haproxy/haproxy-${HAPROXY_VERSION}.tar.gz
curl -L  http://storage.corpintra.plus/cfssl/cfssl_${CFSSL_VERSION}_linux_amd64 -o cfssl
curl -L  http://storage.corpintra.plus/cfssl/cfssl-certinfo_${CFSSL_VERSION}_linux_amd64 -o cfssl-certinfo
curl -L  http://storage.corpintra.plus/cfssl/cfssljson_${CFSSL_VERSION}_linux_amd64 -o cfssljson
}

DOWNLOAD

tar -zxf kubernetes-server-linux-amd64.tar.gz
tar -zxf etcd-${ETCD_VERSION}-linux-amd64.tar.gz
mkdir -p crictl; tar -zxf crictl-${CRICTL_VERSION}-linux-amd64.tar.gz -C crictl;
mkdir -p cni/bin; tar -zxf cni-plugins-linux-amd64-${CNI_PLUGINS_VERSION}.tgz -C cni/bin;
mkdir -p helm; tar -zxf helm-${HELM_VERSION}-linux-amd64.tar.gz -C helm

