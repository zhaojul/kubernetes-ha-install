#!/bin/bash
. ./.env

# IMAGE_REGISTRY="registry.cn-hangzhou.aliyuncs.com"
IMAGE_REGISTRY="docker.io"

helm upgrade kube-state-metrics \
    --kubeconfig ./work/pki/admin.conf \
    --namespace kube-system \
    --create-namespace \
    --debug \
    --wait \
    --install \
    --atomic \
    --set image.repository="${IMAGE_REGISTRY}kubelibrary/kube-state-metrics" \
    --set image.tag="v2.5.0" \
    --set podSecurityPolicy.enabled="true" \
    ./app/kube-state-metrics/kube-state-metrics-4.16.0.tgz

