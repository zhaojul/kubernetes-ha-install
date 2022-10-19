#!/bin/bash
. ./.env

# Default Registry
controller_image_registry="docker.io"
controller_image_image="kubelibrary/ingress-nginx-controller"
controller_admissionWebhooks_patch_image_registry="docker.io"
controller_admissionWebhooks_patch_image_image="kubelibrary/kube-webhook-certgen"
defaultBackend_image_registry="docker.io"
defaultBackend_image_image="kubelibrary/defaultbackend-amd64"

helm upgrade ingress-nginx \
   --kubeconfig ./work/pki/admin.conf \
   --namespace ingress-nginx \
   --create-namespace \
   --debug \
   --install \
   --wait \
   --atomic \
   --timeout 3m0s \
   --set controller.kind="Deployment" \
   --set controller.replicaCount="3" \
   --set controller.minAvailable="1" \
   --set controller.image.registry="${controller_image_registry}" \
   --set controller.image.image="${controller_image_image}" \
   --set controller.image.digest="" \
   --set controller.ingressClassResource.name="nginx" \
   --set controller.ingressClassResource.enable="true" \
   --set controller.ingressClassResource.default="false" \
   --set controller.service.enabled="true" \
   --set controller.service.type="NodePort" \
   --set controller.service.enableHttps="false" \
   --set controller.service.nodePorts.http="32080" \
   --set controller.service.nodePorts.https="32443" \
   --set controller.admissionWebhooks.enabled="false" \
   --set controller.admissionWebhooks.patch.image.registry="${controller_admissionWebhooks_patch_image_registry}" \
   --set controller.admissionWebhooks.patch.image.image="${controller_admissionWebhooks_patch_image_image}" \
   --set controller.admissionWebhooks.patch.image.digest="" \
   --set defaultBackend.enabled="true" \
   --set defaultBackend.name="defaultbackend" \
   --set defaultBackend.image.registry="${defaultBackend_image_registry}" \
   --set defaultBackend.image.image="${defaultBackend_image_image}" \
   --set defaultBackend.replicaCount="1" \
   --set defaultBackend.minAvailable="1" \
   --set rbac.create="true" \
   --set serviceAccount.create="true" \
   --set podSecurityPolicy.enabled="true" \
   ./app/ingress-nginx/ingress-nginx-4.2.5.tgz

