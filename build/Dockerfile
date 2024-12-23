FROM ubuntu:20.04

COPY ./assets/sources.list /etc/apt/sources.list

COPY ./tools /root/tools/

COPY ./scripts/entry.sh /app/entry.sh

# 安装环境
RUN apt-get update && apt-get full-upgrade -y && \
    apt-get install -y openssl wget curl default-jdk git unzip gradle dos2unix tree net-tools neovim inetutils-ping sudo python3-pip ssh nginx mysql-server && \
    /bin/python3 -m pip install PyMysql

WORKDIR /root/tools/generator

RUN ln -sf /usr/bin/python3 /usr/bin/python && \
    ln -sf /usr/bin/pip3 /usr/bin/pip && \
    scripts/install.sh && \
    chmod +x /app/entry.sh

WORKDIR /root/tools

ENTRYPOINT ["/app/entry.sh"]