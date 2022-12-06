#!/bin/bash
. ./.env
. ./.version
echo ">>>>>> 部署coredns <<<<<<"

COREDNS_IMAGE="docker.io/kubelibrary/coredns"

chmod +x ./config/coredns/deploy.sh
./config/coredns/deploy.sh -i ${KUBE_DNS_SVC_IP} -d ${KUBE_DNS_DOMAIN} -m ${COREDNS_IMAGE} -v ${COREDNS_VERSION} | tee ./work/coredns.yaml
kubectl --kubeconfig=./work/pki/admin.conf apply -f ./work/coredns.yaml

