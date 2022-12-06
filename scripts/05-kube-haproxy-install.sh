#!/bin/bash
. ./.env
. ./.version
echo ">>>>>> 部署haproxy <<<<<<"
echo ">>> 生成HAproxy的配置"
cat > ./work/kubeapi.cfg << EOF
#---------------------------------------------------------------------
frontend  kubernetes-apiserver
   bind   0.0.0.0:6443
   mode   tcp
   default_backend   apiserver-backend
#---------------------------------------------------------------------
backend   apiserver-backend
    balance     roundrobin
    mode        tcp
    server      ${MASTER_NAMES[0]} ${MASTER_IPS[0]}:6443 check weight 1 maxconn 1000 check inter 2000 rise 2 fall 3
    server      ${MASTER_NAMES[1]} ${MASTER_IPS[1]}:6443 check weight 1 maxconn 1000 check inter 2000 rise 2 fall 3
    server      ${MASTER_NAMES[2]} ${MASTER_IPS[2]}:6443 check weight 1 maxconn 1000 check inter 2000 rise 2 fall 3
#---------------------------------------------------------------------
EOF

echo ">>>>>> 正在导入HAproxy的配置并启动服务 <<<<<<"
for haproxy_ip in ${HAPROXY_IP};
  do
    echo ">>> ${haproxy_ip}"
    ssh root@${haproxy_ip} """
        hostnamectl set-hostname ${HAPROXY_NAME};
        groupadd -r haproxy
        useradd -r -g haproxy -s /sbin/nologin -d /var/lib/haproxy -c 'haproxy' haproxy
        mkdir -p /var/lib/haproxy /etc/haproxy/conf.d
        chown -Rf haproxy:haproxy /var/lib/haproxy 
        yum -y install make gcc gcc-c++ openssl openssl-devel pcre pcre-devel systemd systemd-devel zip unzip zlib-devel pcre pcre-devel;
        """
    scp -r ./config/haproxy/haproxy.cfg root@${haproxy_ip}:/etc/haproxy/haproxy.cfg
    scp -r ./work/kubeapi.cfg root@${haproxy_ip}:/etc/haproxy/conf.d/kubeapi.cfg
    scp -r ./systemd/haproxy.service root@${haproxy_ip}:/etc/systemd/system/haproxy.service
    scp -r ./work/components/haproxy-${HAPROXY_VERSION}.tar.gz root@${haproxy_ip}:/tmp/haproxy-${HAPROXY_VERSION}.tar.gz
    ssh root@${haproxy_ip} """
        cd /tmp && tar -zxf haproxy-${HAPROXY_VERSION}.tar.gz && cd haproxy-${HAPROXY_VERSION}
        make TARGET=linux-glic USE_GETADDRINFO=1 USE_PCRE=1 USE_OPENSSL=1 USE_EPOLL=1 USE_ZLIB=1 USE_PROMEX=1 USE_SYSTEMD=1
        make install PREFIX=/etc/haproxy SBINDIR=/sbin MANDIR=/usr/share/man DOCDIR=/usr/share/doc
        haproxy -v
        systemctl enable --now haproxy.service; sleep 3s; systemctl status haproxy.service; sleep 3s; reboot;
        """
  done
  
for haproxy_ip in ${HAPROXY_IP};
 do
  while true
  do
    echo "" | telnet ${haproxy_ip} 6443 | grep 'Escape'
    if [ $? -eq 0 ]; then
      echo " ${haproxy_ip} haproxy is running"
      sleep 5s
      break
    else
      echo " ${haproxy_ip} haproxy not running..."
      sleep 5s
    fi
  done
done


