#!/bin/bash
. ./.env
echo ">>>>>> 部署haproxy <<<<<<"
echo ">>> 生成HAproxy的配置"
cat > ./work/haproxy.cfg << EOF
global
    log         127.0.0.1 local2
    chroot      /var/lib/haproxy
    pidfile     /var/run/haproxy.pid
    maxconn     6000
    user        haproxy
    group       haproxy
    daemon
    stats socket /var/lib/haproxy/stats
#---------------------------------------------------------------------
defaults
    mode                    tcp
    log                     global
    option                  tcplog
    option                  dontlognull
    option                  redispatch
    retries                 3
    timeout http-request    10s
    timeout queue           1m
    timeout connect         10s
    timeout client          1m
    timeout server          1m
    timeout http-keep-alive 10s
    timeout check           10s
    maxconn                 3000
#---------------------------------------------------------------------
listen stats
    bind 0.0.0.0:9100
    mode  http
    stats uri /status
    stats refresh 30s
    stats realm "Haproxy Manager"
    stats auth admin:admin
    stats hide-version
    stats admin if TRUE
#---------------------------------------------------------------------
frontend  kubernetes-apiserver
   bind *:6443
   mode tcp
   default_backend      kubernetes-apiserver
#---------------------------------------------------------------------
backend   kubernetes-apiserver
    balance     roundrobin
    mode        tcp
    server      ${MASTER_NAMES[0]} ${MASTER_IPS[0]}:6443 check weight 1 maxconn 1000 check inter 2000 rise 2 fall 3
    server      ${MASTER_NAMES[1]} ${MASTER_IPS[1]}:6443 check weight 1 maxconn 1000 check inter 2000 rise 2 fall 3
    server      ${MASTER_NAMES[2]} ${MASTER_IPS[2]}:6443 check weight 1 maxconn 1000 check inter 2000 rise 2 fall 3
#---------------------------------------------------------------------
EOF

echo ">>>>>> 正在导入HAproxy的配置并启动服务 <<<<<<"
for haproxy_ip in ${HAPROXY_IP}
  do
    echo ">>> ${haproxy_ip}"
    ssh root@${haproxy_ip} "hostnamectl set-hostname ${HAPROXY_NAME}; yum -y install haproxy;"
    scp -r ./work/haproxy.cfg root@${haproxy_ip}:/etc/haproxy/haproxy.cfg
    ssh root@${haproxy_ip} "systemctl enable --now haproxy.service; sleep 3s; systemctl status haproxy.service; sleep 3s; reboot;"
  done


