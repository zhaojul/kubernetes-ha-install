#!/bin/bash
. ./.env

IMAGE_REPOSITORY="docker.io/kubelibrary/kube-state-metrics"

helm upgrade kube-state-metrics \
    --kubeconfig ./work/pki/admin.conf \
    --namespace kube-system \
    --create-namespace \
    --debug \
    --wait \
    --install \
    --atomic \
    --set image.repository="${IMAGE_REPOSITORY}" \
    --set image.tag="v2.5.0" \
    --set podSecurityPolicy.enabled="true" \
    ./app/kube-state-metrics/kube-state-metrics-4.16.0.tgz


