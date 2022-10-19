#!/bin/bash
. ./.env
echo ">>>>>> 部署apiserver <<<<<<"
echo ">>>>>>推送kube-apiserver,kubeadm,kubectl到所有Master节点"
for master_ip in ${MASTER_IPS[@]}
do
  echo ">>> ${master_ip}"
  scp -r ./work/components/helm/linux-amd64/helm root@${master_ip}:/usr/bin/helm
  scp -r ./work/components/kubernetes/server/bin/kubeadm root@${master_ip}:/usr/bin/kubeadm
  scp -r ./work/components/kubernetes/server/bin/kubectl root@${master_ip}:/usr/bin/kubectl
  scp -r ./work/components/kubernetes/server/bin/kube-apiserver root@${master_ip}:/usr/bin/kube-apiserver
  ssh root@${master_ip} "chmod +x /usr/bin/{kube-apiserver,kubeadm,kubectl,helm}; mkdir -p /etc/kubernetes/config; mkdir -p /var/log/kubernetes;"
done

ENCRYPTION_KEY="`head -c 32 /dev/urandom | base64`"

cat > ./work/encryption-config.yaml <<EOF
kind: EncryptionConfiguration
apiVersion: apiserver.config.k8s.io/v1
resources:
  - resources:
      - secrets
    providers:
      - aescbc:
          keys:
          - name: key1
            secret: ${ENCRYPTION_KEY}
      - identity: {}
EOF

echo ">>> 分发kube-apiserver配置文件并启动服务"
for master_ip in ${MASTER_IPS[@]}
do
{
  echo ">>> ${master_ip}"
  scp -r ./work/encryption-config.yaml root@${master_ip}:/etc/kubernetes/config/encryption-config.yaml
  scp -r ./config/audit-policy/audit-policy.yaml root@${master_ip}:/etc/kubernetes/config/audit-policy.yaml
  scp -r ./systemd/kube-apiserver.service root@${master_ip}:/etc/systemd/system/kube-apiserver.service
  ssh root@${master_ip} "systemctl daemon-reload && systemctl enable kube-apiserver --now;"
}&
done
wait

sleep 10s
echo ">>> 检查kube-apiserver服务"
for master_ip in ${MASTER_IPS[@]}
do
{
  ssh root@${master_ip} "systemctl status kube-apiserver |grep 'Active:';"
  ssh root@${master_ip} "mkdir -p ~/.kube; cp -r /etc/kubernetes/admin.conf ~/.kube/config; chmod 700 ~/.kube; chmod 600 ~/.kube/config;"
  ssh root@${master_ip} "kubectl cluster-info; kubectl get all --all-namespaces; kubectl get componentstatuses"
}&
done
wait

kubectl --kubeconfig=./work/pki/admin.conf apply -f ./config/kubelet-rbac-role/kubelet-rbac-role.yaml


