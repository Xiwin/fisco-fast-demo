#!/bin/bash

# 启动所有服务
service ssh start
service mysql start
service nginx start

echo "配置root密码"
echo root:123456 | chpasswd

echo "配置root允许登录"
sed -i -E 's/^#(PermitRootLogin).*/\1 yes/g' /etc/ssh/sshd_config
service ssh restart

tail -f /dev/null