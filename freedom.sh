#!/bin/bash

function blue(){
	echo -e "\e[34m\e[01m $1 \e[0m"
}
function green(){
	echo -e "\e[32m\e[01m $1 \e[0m"
}
function red(){
	echo -e "\e[31m\e[01m $1 \e[0m"
}
function yellow(){
	echo -e "\e[33m\e[01m $1 \e[0m"
}
function pink(){
	echo -e "\e[35m\e[01m $1 \e[0m"
}

# 安装常用软件包
sudo apt-get -y update && sudo apt-get -y install unzip zip wget curl nano sudo ufw socat ntp ntpdate gcc git xz-utils

# 读取域名
echo
echo
green "======================"
green " 输入解析到此VPS的域名"
green "======================"
read domain
# 校验域名

echo
echo
green "===============获取本机ip地址==============="
# 获取本机ip地址
# curl icanhazip.com
# curl ident.me
# curl ipecho.net/plain
# curl whatismyip.akamai.com
# curl tnx.nl/ip
# curl myip.dnsomatic.com
# curl ip.appspot.com
ipAddr=$(curl ifconfig.me)
pink "ip: $ipAddr"

# 读取Cloudflare Email和Key
# read CF_Email
# 校验email
# read CF_Key
# 添加Cloudflare域名解析



echo
echo
green "===============安装nginx==============="
# 安装nginx
sudo apt-get install -y nginx || exit 100
yellow "nginx安装成功，开始配置nginx"
sudo mkdir /etc/nginx/ssl

# 删除默认配置
sudo rm /etc/nginx/sites-enabled/default
# 生成配置文件
sudo cat > /etc/nginx/nginx.conf <<-EOF
user  root;
worker_processes  auto;
error_log /var/log/nginx/error.log;
pid /run/nginx.pid;
events {
    worker_connections  1024;
}
http {
    include       /etc/nginx/mime.types;
    default_type  application/octet-stream;
    log_format  main  '\$remote_addr - \$remote_user [\$time_local] "\$request" '
                      '\$status \$body_bytes_sent "\$http_referer" '
                      '"\$http_user_agent" "\$http_x_forwarded_for"';
    access_log  /var/log/nginx/access.log  main;
    sendfile        on;
    #tcp_nopush     on;
    keepalive_timeout  120;
    client_max_body_size 20m;
    #gzip  on;
	include /etc/nginx/conf.d/*.conf;
	include /etc/nginx/sites-enabled/*;
}
EOF

cat > /etc/nginx/sites-available/$domain.conf<<-EOF
server {
    listen 127.0.0.1:80 default_server;

    server_name $domain;

    location / {
        root /usr/share/nginx/html;
        index index.php index.html index.htm;
    }
    # error_page   500 502 503 504  /50x.html;
    # location = /50x.html {
    #     root   /usr/share/nginx/html;
    # }
}

server {
    listen 127.0.0.1:80;

    server_name $ipAddr;
    return 301 https://$domain$request_uri;
}

server {
    listen 0.0.0.0:80;
    listen [::]:80;

    server_name _;
   	return 301 https://$host$request_uri;
}
EOF

# 配置nginx服务
sudo ln -s /etc/nginx/sites-available/$domain.conf /etc/nginx/sites-enabled/

# 配置马甲站点
rm -rf /usr/share/nginx/html
cd /usr/share/nginx/
wget https://raw.githubusercontent.com/skycar8/free/master/car.zip
unzip car.zip
rm car.zip

# 启动nginx
sudo systemctl restart nginx  || exit 101
sudo systemctl status nginx

# nginx开机启动
sudo systemctl enable nginx.service



echo
echo
green "===============安装SSL证书==============="
# 安装acme
curl https://get.acme.sh | sh  || exit 102

# 申请证书
~/.acme.sh/acme.sh  --issue  -d $domain  --nginx || exit 103
# or ~/.acme.sh/acme.sh  --issue  -d $domain  --webroot /usr/share/nginx/html/

# 安装证书
~/.acme.sh/acme.sh  --installcert  -d  $domain   \
        --key-file   /etc/nginx/ssl/$domain.key \
        --fullchain-file /etc/nginx/ssl/fullchain.cer \
        --reloadcmd  "service nginx force-reload"

# 自动更新证书
acme.sh  --upgrade  --auto-upgrade



echo
echo
green "===============安装trojan==============="
# 安装trojan
sudo bash -c "$(curl -fsSL https://raw.githubusercontent.com/trojan-gfw/trojan-quickstart/master/trojan-quickstart.sh)" || return 104

# 生成随机密码
sudo password=$(cat /dev/urandom | head -1 | md5sum | head -c 32)

# 生成配置文件
sudo cat > /usr/local/etc/trojan/config.json <<-EOF
{
    "run_type": "server",
    "local_addr": "0.0.0.0",
    "local_port": 443,
    "remote_addr": "127.0.0.1",
    "remote_port": 80,
    "password": [
        $password
    ],
    "log_level": 1,
    "ssl": {
        "cert": "/etc/nginx/ssl/fullchain.cer",
        "key": "/etc/nginx/ssl/$domain.key",
        "key_password": "",
        "cipher": "ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384",
        "cipher_tls13": "TLS_AES_128_GCM_SHA256:TLS_CHACHA20_POLY1305_SHA256:TLS_AES_256_GCM_SHA384",
        "prefer_server_cipher": true,
        "alpn": [
            "http/1.1"
        ],
        "alpn_port_override": {
            "h2": 81
        },
        "reuse_session": true,
        "session_ticket": false,
        "session_timeout": 600,
        "plain_http_response": "",
        "curves": "",
        "dhparam": ""
    },
    "tcp": {
        "prefer_ipv4": false,
        "no_delay": true,
        "keep_alive": true,
        "reuse_port": false,
        "fast_open": false,
        "fast_open_qlen": 20
    },
    "mysql": {
        "enabled": false,
        "server_addr": "127.0.0.1",
        "server_port": 3306,
        "database": "trojan",
        "username": "trojan",
        "password": "",
        "cafile": ""
    }
}
EOF

# 启动trojan
sudo systemctl restart trojan  || exit 105
sudo systemctl status trojan

# torjan开机启动
sudo systemctl enable trojan.service


echo
echo
green "===============安装OK==============="
green "trojan连接密码：$password"

# 上传trojan配置文件到github
# 导出证书-上传github-OpenWrt更新证书-Synology更新证书



echo
echo
green "===============开启bbr加速==============="
# 开启bbr加速
sudo echo net.core.default_qdisc=fq >> /etc/sysctl.conf
sudo echo net.ipv4.tcp_congestion_control=bbr >> /etc/sysctl.conf
sysctl -p

# sysctl net.ipv4.tcp_available_congestion_control

#rootMF8-BIZ sysctl net.ipv4.tcp_available_congestion_control
#net.ipv4.tcp_available_congestion_control = bbr cubic reno

lsmod | grep bbr
#tcp_bbr                20480  11
