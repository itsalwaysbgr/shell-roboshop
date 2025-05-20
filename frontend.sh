#!/bin/bash

# Variables
USERID=$(id -u)
R="\e[31m"
G="\e[32m"
N="\e[0m"
LOGS_FOLDER="/var/log/roboshop-logs"
SCRIPT_NAME=$(basename "$0" | cut -d"." -f1)
LOG_FILE="${LOGS_FOLDER}/${SCRIPT_NAME}.log"

mkdir -p "$LOGS_FOLDER"

# Root check
if [ "$USERID" -ne 0 ]; then
    echo -e "${R}ERROR: Please run this script with root access${N}" | tee -a "$LOG_FILE"
    exit 1
else
    echo "You are running with root access" | tee -a "$LOG_FILE"
fi

# Validate function
validate() {
    if [ "$1" -eq 0 ]; then
        echo -e "$2 ... ${G}SUCCESS${N}" | tee -a "$LOG_FILE"
    else
        echo -e "$2 ... ${R}FAILURE${N}" | tee -a "$LOG_FILE"
        exit 1
    fi
}

# Disable and enable nginx module
dnf module disable nginx -y >> "$LOG_FILE" 2>&1
validate $? "Disabling nginx module"

dnf module enable nginx:1.24 -y >> "$LOG_FILE" 2>&1
validate $? "Enabling nginx:1.24 module"

# Install nginx
dnf install nginx -y >> "$LOG_FILE" 2>&1
validate $? "Installing nginx"

# Start and enable nginx
systemctl enable nginx >> "$LOG_FILE" 2>&1
validate $? "Enabling nginx service"

systemctl start nginx >> "$LOG_FILE" 2>&1
validate $? "Starting nginx service"

# Remove default content
rm -rf /usr/share/nginx/html/* >> "$LOG_FILE" 2>&1
validate $? "Removing default nginx content"

# Download frontend content
curl -o /tmp/frontend.zip https://roboshop-artifacts.s3.amazonaws.com/frontend-v3.zip >> "$LOG_FILE" 2>&1
validate $? "Downloading frontend content"

# Extract frontend content
cd /usr/share/nginx/html
unzip /tmp/frontend.zip >> "$LOG_FILE" 2>&1
validate $? "Extracting frontend content"

# Configure nginx.conf
cat > /etc/nginx/nginx.conf << 'EOF'
user nginx;
worker_processes auto;
error_log /var/log/nginx/error.log notice;
pid /run/nginx.pid;

include /usr/share/nginx/modules/*.conf;

events {
    worker_connections 1024;
}

http {
    log_format  main  '$remote_addr - $remote_user [$time_local] "$request" '
                      '$status $body_bytes_sent "$http_referer" '
                      '"$http_user_agent" "$http_x_forwarded_for"';

    access_log  /var/log/nginx/access.log  main;

    sendfile            on;
    tcp_nopush          on;
    keepalive_timeout   65;
    types_hash_max_size 4096;

    include             /etc/nginx/mime.types;
    default_type        application/octet-stream;

    include /etc/nginx/conf.d/*.conf;

    server {
        listen       80;
        listen       [::]:80;
        server_name  _;
        root         /usr/share/nginx/html;

        include /etc/nginx/default.d/*.conf;

        error_page 404 /404.html;
        location = /404.html {
        }

        error_page 500 502 503 504 /50x.html;
        location = /50x.html {
        }

        location /images/ {
          expires 5s;
          root   /usr/share/nginx/html;
          try_files $uri /images/placeholder.jpg;
        }
        location /api/catalogue/ { proxy_pass http://catalogue.daws86s.site:8080/; }
        location /api/user/ { proxy_pass http://localhost:8080/; }
        location /api/cart/ { proxy_pass http://localhost:8080/; }
        location /api/shipping/ { proxy_pass http://localhost:8080/; }
        location /api/payment/ { proxy_pass http://localhost:8080/; }

        location /health {
          stub_status on;
          access_log off;
        }

    }
}
EOF
validate $? "Configuring nginx.conf"

# Restart nginx to apply changes
systemctl restart nginx >> "$LOG_FILE" 2>&1
validate $? "Restarting nginx"

echo -e "${G}Frontend setup completed. Please update proxy_pass addresses in /etc/nginx/nginx.conf as needed.${N}" | tee -a "$LOG_FILE"