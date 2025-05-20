#!/bin/bash

# Variables
USERID=$(id -u)
R="\e[31m"
G="\e[32m"
N="\e[0m"
LOGS_FOLDER="/var/log/roboshop-logs"
SCRIPT_NAME=$(basename "$0" | cut -d"." -f1)
LOG_FILE="${LOGS_FOLDER}/${SCRIPT_NAME}.log"
SCRIPT_DIR=$PWD

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

# Disable nginx module only if enabled
if dnf module list nginx | grep -qE '^\s*nginx\s+[^\s]+\s+enabled'; then
    dnf module disable nginx -y >> "$LOG_FILE" 2>&1
    validate $? "Disabling nginx module"
else
    echo "nginx module already disabled" | tee -a "$LOG_FILE"
fi

# Enable nginx:1.24 module only if not already enabled
if ! dnf module list nginx:1.24 | grep -qE '^\s*nginx\s+1.24\s+enabled'; then
    dnf module enable nginx:1.24 -y >> "$LOG_FILE" 2>&1
    validate $? "Enabling nginx:1.24 module"
else
    echo "nginx:1.24 module already enabled" | tee -a "$LOG_FILE"
fi

# Install nginx only if not installed
if ! rpm -q nginx &>/dev/null; then
    dnf install nginx -y >> "$LOG_FILE" 2>&1
    validate $? "Installing nginx"
else
    echo "nginx already installed" | tee -a "$LOG_FILE"
fi

# Enable nginx service
systemctl enable nginx >> "$LOG_FILE" 2>&1
validate $? "Enabling nginx service"

# Start nginx service if not running
if ! systemctl is-active --quiet nginx; then
    systemctl start nginx >> "$LOG_FILE" 2>&1
    validate $? "Starting nginx service"
else
    echo "nginx service already running" | tee -a "$LOG_FILE"
fi

# Remove default content only if files exist
if [ "$(ls -A /usr/share/nginx/html 2>/dev/null)" ]; then
    rm -rf /usr/share/nginx/html/* >> "$LOG_FILE" 2>&1
    validate $? "Removing default nginx content"
else
    echo "No default nginx content to remove" | tee -a "$LOG_FILE"
fi

# Download frontend content only if not already downloaded
if [ ! -f /tmp/frontend.zip ]; then
    curl -o /tmp/frontend.zip https://roboshop-artifacts.s3.amazonaws.com/frontend-v3.zip >> "$LOG_FILE" 2>&1
    validate $? "Downloading frontend content"
else
    echo "frontend.zip already downloaded" | tee -a "$LOG_FILE"
fi

# Extract frontend content only if not already extracted
cd /usr/share/nginx/html || exit 1
if [ ! -f index.html ]; then
    unzip /tmp/frontend.zip >> "$LOG_FILE" 2>&1
    validate $? "Extracting frontend content"
else
    echo "Frontend content already extracted" | tee -a "$LOG_FILE"
fi

# Copy nginx.conf only if different
if ! cmp -s "$SCRIPT_DIR/nginx.conf" /etc/nginx/nginx.conf; then
    cp "$SCRIPT_DIR/nginx.conf" /etc/nginx/nginx.conf >> "$LOG_FILE" 2>&1
    validate $? "Configuring nginx.conf"
else
    echo "nginx.conf already up to date" | tee -a "$LOG_FILE"
fi

# Restart nginx to apply changes
systemctl restart nginx >> "$LOG_FILE" 2>&1
validate $? "Restarting nginx"

echo -e "${G}Frontend setup completed. Please update proxy_pass addresses in /etc/nginx/nginx.conf as needed.${N}" | tee -a "$LOG_FILE"