#!/bin/bash
. ./.env
rm -rf ./work/pki
mkdir -p ./work/pki/etcd

echo ">>>>>> 生成CA根证书 <<<<<<"

cat > ./work/pki/ca-config.json <<EOF
{
  "signing": {
    "default": {
      "expiry": "876000h"
    },
    "profiles": {
      "etcd": {
        "usages": [
            "signing",
            "key encipherment",
            "server auth",
            "client auth"
        ],
        "expiry": "876000h"
      },
      "kubernetes": {
        "usages": [
            "signing",
            "key encipherment",
            "server auth",
            "client auth"
        ],
        "expiry": "876000h"
      }
    }
  }
}
EOF

cat > ./work/pki/etcd-ca-csr.json <<EOF
{
  "CN": "etcd-ca",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "ca": {
    "expiry": "876000h"
 }
}
EOF

cat > ./work/pki/kube-ca-csr.json <<EOF
{
  "CN": "kubernetes",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "ca": {
    "expiry": "876000h"
 }
}
EOF

cfssl gencert -initca ./work/pki/etcd-ca-csr.json | cfssljson -bare ./work/pki/etcd/ca
openssl rsa  -in ./work/pki/etcd/ca-key.pem -out ./work/pki/etcd/ca.key
openssl x509 -in ./work/pki/etcd/ca.pem -out ./work/pki/etcd/ca.crt

cfssl gencert -initca ./work/pki/kube-ca-csr.json | cfssljson -bare ./work/pki/ca
openssl rsa  -in ./work/pki/ca-key.pem -out ./work/pki/ca.key
openssl x509 -in ./work/pki/ca.pem -out ./work/pki/ca.crt

for master in ${MASTER_IPS[@]};
do
  ssh root@${master} "mkdir -p /etc/kubernetes/pki/etcd";
  scp -r ./work/pki/etcd/ca.key root@${master}:/etc/kubernetes/pki/etcd/ca.key;
  scp -r ./work/pki/etcd/ca.crt root@${master}:/etc/kubernetes/pki/etcd/ca.crt;
  scp -r ./work/pki/ca.key root@${master}:/etc/kubernetes/pki/ca.key;
  scp -r ./work/pki/ca.crt root@${master}:/etc/kubernetes/pki/ca.crt;
done

for node in ${NODE_IPS[@]};
do
  ssh root@${node} "mkdir -p /etc/kubernetes/pki"
  scp -r ./work/pki/ca.crt root@${node}:/etc/kubernetes/pki/ca.crt;
done

echo ">>>>>> 生成etcd相关证书 <<<<<<"

i=0
for etcd_ip in ${MASTER_IPS[@]};
do
cat > ./work/pki/etcd/server-${etcd_ip}-csr.json <<EOF
{
  "CN": "${MASTER_NAMES[i]}",
  "hosts": [
    "${MASTER_NAMES[i]}",
    "localhost",
    "${MASTER_IPS[i]}",
    "127.0.0.1",
    "0000:0000:0000:0000:0000:0000:0000:0001"
  ],
  "key": {
    "algo": "rsa",
    "size": 2048
  }
}
EOF

cat > ./work/pki/etcd/peer-${etcd_ip}-csr.json <<EOF
{
  "CN": "${MASTER_NAMES[i]}",
  "hosts": [
    "${MASTER_NAMES[i]}",
    "localhost",
    "${MASTER_IPS[i]}",
    "127.0.0.1",
    "0000:0000:0000:0000:0000:0000:0000:0001"
  ],
  "key": {
    "algo": "rsa",
    "size": 2048
  }
}
EOF

cfssl gencert -ca=./work/pki/etcd/ca.crt -ca-key=./work/pki/etcd/ca.key -config=./work/pki/ca-config.json -profile=etcd ./work/pki/etcd/server-${etcd_ip}-csr.json | cfssljson -bare ./work/pki/etcd/server-${etcd_ip}
openssl rsa  -in ./work/pki/etcd/server-${etcd_ip}-key.pem -out ./work/pki/etcd/server-${etcd_ip}.key
openssl x509 -in ./work/pki/etcd/server-${etcd_ip}.pem -out ./work/pki/etcd/server-${etcd_ip}.crt
scp -r ./work/pki/etcd/server-${etcd_ip}.key root@${etcd_ip}:/etc/kubernetes/pki/etcd/server.key;
scp -r ./work/pki/etcd/server-${etcd_ip}.crt root@${etcd_ip}:/etc/kubernetes/pki/etcd/server.crt;

cfssl gencert -ca=./work/pki/etcd/ca.crt -ca-key=./work/pki/etcd/ca.key -config=./work/pki/ca-config.json -profile=etcd ./work/pki/etcd/peer-${etcd_ip}-csr.json | cfssljson -bare ./work/pki/etcd/peer-${etcd_ip}
openssl rsa  -in ./work/pki/etcd/peer-${etcd_ip}-key.pem -out ./work/pki/etcd/peer-${etcd_ip}.key
openssl x509 -in ./work/pki/etcd/peer-${etcd_ip}.pem -out ./work/pki/etcd/peer-${etcd_ip}.crt
scp -r ./work/pki/etcd/peer-${etcd_ip}.key root@${etcd_ip}:/etc/kubernetes/pki/etcd/peer.key;
scp -r ./work/pki/etcd/peer-${etcd_ip}.crt root@${etcd_ip}:/etc/kubernetes/pki/etcd/peer.crt;

let i++
done

cat > ./work/pki/etcd/healthcheck-client-csr.json <<EOF
{
  "CN": "kube-etcd-healthcheck-client",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "O": "system:masters"
    }
  ]
}
EOF

cfssl gencert -ca=./work/pki/etcd/ca.crt -ca-key=./work/pki/etcd/ca.key -config=./work/pki/ca-config.json -profile=etcd ./work/pki/etcd/healthcheck-client-csr.json | cfssljson -bare ./work/pki/etcd/healthcheck-client
openssl rsa  -in ./work/pki/etcd/healthcheck-client-key.pem -out ./work/pki/etcd/healthcheck-client.key
openssl x509 -in ./work/pki/etcd/healthcheck-client.pem -out ./work/pki/etcd/healthcheck-client.crt

for etcd_ip in ${MASTER_IPS[@]};
do
  scp -r ./work/pki/etcd/healthcheck-client.key root@${etcd_ip}:/etc/kubernetes/pki/etcd/healthcheck-client.key;
  scp -r ./work/pki/etcd/healthcheck-client.crt root@${etcd_ip}:/etc/kubernetes/pki/etcd/healthcheck-client.crt;
done


cat > ./work/pki/apiserver-etcd-client-csr.json <<EOF
{
  "CN": "kube-apiserver-etcd-client",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "O": "system:masters"
    }
  ]
}
EOF

cfssl gencert -ca=./work/pki/etcd/ca.crt -ca-key=./work/pki/etcd/ca.key -config=./work/pki/ca-config.json -profile=etcd ./work/pki/apiserver-etcd-client-csr.json | cfssljson -bare ./work/pki/apiserver-etcd-client
openssl rsa  -in ./work/pki/apiserver-etcd-client-key.pem -out ./work/pki/apiserver-etcd-client.key
openssl x509 -in ./work/pki/apiserver-etcd-client.pem -out ./work/pki/apiserver-etcd-client.crt

for etcd_ip in ${MASTER_IPS[@]};
do
  scp -r ./work/pki/apiserver-etcd-client.key root@${etcd_ip}:/etc/kubernetes/pki/apiserver-etcd-client.key;
  scp -r ./work/pki/apiserver-etcd-client.crt root@${etcd_ip}:/etc/kubernetes/pki/apiserver-etcd-client.crt;
done

echo ">>>>>> 生成kubernetes相关证书 <<<<<<"

i=0
for master_ip in ${MASTER_IPS[@]};
do
cat > ./work/pki/apiserver-${master_ip}-csr.json <<EOF
{
  "CN": "kube-apiserver",
  "hosts": [
    "${MASTER_NAMES[i]}",
    "localhost",
    "kubernetes",
    "kubernetes.default",
    "kubernetes.default.svc",
    "kubernetes.default.svc.cluster",
    "kubernetes.default.svc.cluster.local",
    "127.0.0.1",
    "${KUBE_SERVICE_IP}",
    "${MASTER_IPS[i]}",
    "${HAPROXY_IP}"
  ],
  "key": {
    "algo": "rsa",
    "size": 2048
  }
}
EOF

cat > ./work/pki/kube-controller-manager-${master_ip}-csr.json <<EOF
{
  "CN": "system:kube-controller-manager",
  "hosts": [
    "${MASTER_NAMES[i]}",
    "localhost",
    "127.0.0.1",
    "${MASTER_IPS[i]}"
  ],
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "O": "system:kube-controller-manager"
    }
  ] 
}
EOF

cat > ./work/pki/kube-scheduler-${master_ip}-csr.json <<EOF
{
  "CN": "system:kube-scheduler",
  "hosts": [
    "${MASTER_NAMES[i]}",
    "localhost",
    "127.0.0.1",
    "${MASTER_IPS[i]}"
  ],
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "O": "system:kube-scheduler"
    }
  ] 
}
EOF

cfssl gencert -ca=./work/pki/ca.crt -ca-key=./work/pki/ca.key -config=./work/pki/ca-config.json -profile=kubernetes ./work/pki/apiserver-${master_ip}-csr.json | cfssljson -bare ./work/pki/apiserver-${master_ip}
openssl rsa  -in ./work/pki/apiserver-${master_ip}-key.pem -out ./work/pki/apiserver-${master_ip}.key
openssl x509 -in ./work/pki/apiserver-${master_ip}.pem -out ./work/pki/apiserver-${master_ip}.crt
scp -r ./work/pki/apiserver-${master_ip}.key root@${master_ip}:/etc/kubernetes/pki/apiserver.key;
scp -r ./work/pki/apiserver-${master_ip}.crt root@${master_ip}:/etc/kubernetes/pki/apiserver.crt;

cfssl gencert -ca=./work/pki/ca.crt -ca-key=./work/pki/ca.key -config=./work/pki/ca-config.json -profile=kubernetes ./work/pki/kube-controller-manager-${master_ip}-csr.json | cfssljson -bare ./work/pki/kube-controller-manager-${master_ip}
openssl rsa  -in ./work/pki/kube-controller-manager-${master_ip}-key.pem -out ./work/pki/kube-controller-manager-${master_ip}.key
openssl x509 -in ./work/pki/kube-controller-manager-${master_ip}.pem -out ./work/pki/kube-controller-manager-${master_ip}.crt
scp -r ./work/pki/kube-controller-manager-${master_ip}.key root@${master_ip}:/etc/kubernetes/pki/kube-controller-manager.key;
scp -r ./work/pki/kube-controller-manager-${master_ip}.crt root@${master_ip}:/etc/kubernetes/pki/kube-controller-manager.crt;

cfssl gencert -ca=./work/pki/ca.crt -ca-key=./work/pki/ca.key -config=./work/pki/ca-config.json -profile=kubernetes ./work/pki/kube-scheduler-${master_ip}-csr.json | cfssljson -bare ./work/pki/kube-scheduler-${master_ip}
openssl rsa  -in ./work/pki/kube-scheduler-${master_ip}-key.pem -out ./work/pki/kube-scheduler-${master_ip}.key
openssl x509 -in ./work/pki/kube-scheduler-${master_ip}.pem -out ./work/pki/kube-scheduler-${master_ip}.crt
scp -r ./work/pki/kube-scheduler-${master_ip}.key root@${master_ip}:/etc/kubernetes/pki/kube-scheduler.key;
scp -r ./work/pki/kube-scheduler-${master_ip}.crt root@${master_ip}:/etc/kubernetes/pki/kube-scheduler.crt;

kubectl config set-cluster kubernetes --certificate-authority=./work/pki/ca.crt --embed-certs=true --server=https://${master_ip}:6443 --kubeconfig=./work/pki/controller-manager-${master_ip}.conf
kubectl config set-credentials system:kube-controller-manager --client-certificate=./work/pki/kube-controller-manager-${master_ip}.crt --client-key=./work/pki/kube-controller-manager-${master_ip}.key --embed-certs=true --kubeconfig=./work/pki/controller-manager-${master_ip}.conf
kubectl config set-context system:kube-controller-manager@kubernetes --cluster=kubernetes --user=system:kube-controller-manager --kubeconfig=./work/pki/controller-manager-${master_ip}.conf
kubectl config use-context system:kube-controller-manager@kubernetes --kubeconfig=./work/pki/controller-manager-${master_ip}.conf
scp -r ./work/pki/controller-manager-${master_ip}.conf root@${master_ip}:/etc/kubernetes/controller-manager.conf;

kubectl config set-cluster kubernetes --certificate-authority=./work/pki/ca.crt --embed-certs=true --server=https://${master_ip}:6443 --kubeconfig=./work/pki/scheduler-${master_ip}.conf
kubectl config set-credentials system:kube-scheduler --client-certificate=./work/pki/kube-scheduler-${master_ip}.crt --client-key=./work/pki/kube-scheduler-${master_ip}.key --embed-certs=true --kubeconfig=./work/pki/scheduler-${master_ip}.conf
kubectl config set-context system:kube-scheduler@kubernetes --cluster=kubernetes --user=system:kube-scheduler --kubeconfig=./work/pki/scheduler-${master_ip}.conf
kubectl config use-context system:kube-scheduler@kubernetes --kubeconfig=./work/pki/scheduler-${master_ip}.conf
scp -r ./work/pki/scheduler-${master_ip}.conf root@${master_ip}:/etc/kubernetes/scheduler.conf;

let i++
done

#apiserver-kubelet-client
cat > ./work/pki/apiserver-kubelet-client-csr.json <<EOF
{
  "CN": "kube-apiserver-kubelet-client",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "O": "system:masters"
    }
  ]
}
EOF

cfssl gencert -ca=./work/pki/ca.crt -ca-key=./work/pki/ca.key -config=./work/pki/ca-config.json -profile=kubernetes ./work/pki/apiserver-kubelet-client-csr.json | cfssljson -bare ./work/pki/apiserver-kubelet-client
openssl rsa  -in ./work/pki/apiserver-kubelet-client-key.pem -out ./work/pki/apiserver-kubelet-client.key
openssl x509 -in ./work/pki/apiserver-kubelet-client.pem -out ./work/pki/apiserver-kubelet-client.crt

for master_ip in ${MASTER_IPS[@]};
do
  scp -r ./work/pki/apiserver-kubelet-client.key root@${master_ip}:/etc/kubernetes/pki/apiserver-kubelet-client.key;
  scp -r ./work/pki/apiserver-kubelet-client.crt root@${master_ip}:/etc/kubernetes/pki/apiserver-kubelet-client.crt;
done

#kubeconfig for kubectl
cat > ./work/pki/kubernetes-admin-csr.json <<EOF
{
  "CN": "kubernetes-admin",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "O": "system:masters"
    }
  ]
}
EOF

cfssl gencert -ca=./work/pki/ca.crt -ca-key=./work/pki/ca.key -config=./work/pki/ca-config.json -profile=kubernetes ./work/pki/kubernetes-admin-csr.json | cfssljson -bare ./work/pki/kubernetes-admin
openssl rsa  -in ./work/pki/kubernetes-admin-key.pem -out ./work/pki/kubernetes-admin.key
openssl x509 -in ./work/pki/kubernetes-admin.pem -out ./work/pki/kubernetes-admin.crt

kubectl config set-cluster kubernetes --certificate-authority=./work/pki/ca.crt --embed-certs=true --server=https://${HAPROXY_IP}:6443 --kubeconfig=./work/pki/admin.conf
kubectl config set-credentials kubernetes-admin --client-certificate=./work/pki/kubernetes-admin.crt --client-key=./work/pki/kubernetes-admin.key --embed-certs=true --kubeconfig=./work/pki/admin.conf
kubectl config set-context kubernetes-admin@kubernetes --cluster=kubernetes --user=kubernetes-admin --kubeconfig=./work/pki/admin.conf
kubectl config use-context kubernetes-admin@kubernetes --kubeconfig=./work/pki/admin.conf

for master_ip in ${MASTER_IPS[@]};
do
  scp -r ./work/pki/admin.conf root@${master_ip}:/etc/kubernetes/admin.conf;
done

#front-proxy-ca
cat > ./work/pki/front-proxy-ca-csr.json <<EOF
{
  "CN": "front-proxy-ca",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "ca": {
    "expiry": "876000h"
 }
}
EOF

cfssl gencert -initca ./work/pki/front-proxy-ca-csr.json | cfssljson -bare ./work/pki/front-proxy-ca
openssl rsa  -in ./work/pki/front-proxy-ca-key.pem -out ./work/pki/front-proxy-ca.key
openssl x509 -in ./work/pki/front-proxy-ca.pem -out ./work/pki/front-proxy-ca.crt

for node in ${MASTER_IPS[@]};
do
    scp -r ./work/pki/front-proxy-ca.key root@${node}:/etc/kubernetes/pki/front-proxy-ca.key;
    scp -r ./work/pki/front-proxy-ca.crt root@${node}:/etc/kubernetes/pki/front-proxy-ca.crt;
done

#front-proxy-client
cat > ./work/pki/front-proxy-client-csr.json <<EOF
{
  "CN": "front-proxy-client",
  "key": {
    "algo": "rsa",
    "size": 2048
  }
}
EOF

cfssl gencert -ca=./work/pki/front-proxy-ca.crt -ca-key=./work/pki/front-proxy-ca.key -config=./work/pki/ca-config.json -profile=kubernetes ./work/pki/front-proxy-client-csr.json | cfssljson -bare ./work/pki/front-proxy-client
openssl rsa  -in ./work/pki/front-proxy-client-key.pem -out ./work/pki/front-proxy-client.key
openssl x509 -in ./work/pki/front-proxy-client.pem -out ./work/pki/front-proxy-client.crt

#sa
openssl genrsa -out ./work/pki/sa.key 2048
openssl rsa -in ./work/pki/sa.key -pubout -out ./work/pki/sa.pub

for node in ${MASTER_IPS[@]};
do
  scp -r ./work/pki/front-proxy-client.key root@${node}:/etc/kubernetes/pki/front-proxy-client.key;
  scp -r ./work/pki/front-proxy-client.crt root@${node}:/etc/kubernetes/pki/front-proxy-client.crt;
  scp -r ./work/pki/sa.key root@${node}:/etc/kubernetes/pki/sa.key;
  scp -r ./work/pki/sa.pub root@${node}:/etc/kubernetes/pki/sa.pub;
done

#kube-proxy
cat > ./work/pki/kube-proxy-csr.json <<EOF
{
  "CN": "system:kube-proxy",
  "hosts": [],
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "O": "system:kube-proxy"
    }
  ]
}
EOF

cfssl gencert -ca=./work/pki/ca.crt -ca-key=./work/pki/ca.key -config=./work/pki/ca-config.json -profile=kubernetes ./work/pki/kube-proxy-csr.json | cfssljson -bare ./work/pki/kube-proxy
openssl rsa  -in ./work/pki/kube-proxy-key.pem -out ./work/pki/kube-proxy.key
openssl x509 -in ./work/pki/kube-proxy.pem -out ./work/pki/kube-proxy.crt

kubectl config set-cluster kubernetes --certificate-authority=./work/pki/ca.crt --embed-certs=true --server=https://${HAPROXY_IP}:6443 --kubeconfig=./work/pki/kube-proxy.conf
kubectl config set-credentials system:kube-proxy --client-certificate=./work/pki/kube-proxy.crt --client-key=./work/pki/kube-proxy.key --embed-certs=true --kubeconfig=./work/pki/kube-proxy.conf
kubectl config set-context system:kube-proxy@kubernetes --cluster=kubernetes --user=system:kube-proxy --kubeconfig=./work/pki/kube-proxy.conf
kubectl config use-context system:kube-proxy@kubernetes --kubeconfig=./work/pki/kube-proxy.conf

for node in ${NODE_IPS[@]};
do
  ssh root@${node} "mkdir -p /var/lib/kube-proxy";
  scp -r ./work/pki/kube-proxy.conf root@${node}:/var/lib/kube-proxy/kubeconfig.conf;
done

