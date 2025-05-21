#!/bin/bash

# Variables
USERID=$(id -u)
R="\e[31m"
G="\e[32m"
N="\e[0m"
LOGS_FOLDER="/var/log/roboshop-logs"
SCRIPT_NAME=$(basename "$0" | cut -d"." -f1)
LOG_FILE="${LOGS_FOLDER}/${SCRIPT_NAME}.log"
FRONTEND_ZIP="/tmp/frontend.zip"
SCRIPT_DIR=$PWD

mkdir -p "$LOGS_FOLDER"

# Root check
if [ "$USERID" -ne 0 ]; then
    echo -e "${R}ERROR: Please run this script with root access${N}" | tee -a "$LOG_FILE"
    exit 1
fi

echo "You are running with root access" | tee -a "$LOG_FILE"

# Validate function
validate() {
    if [ "$1" -eq 0 ]; then
        echo -e "$2 ... ${G}SUCCESS${N}" | tee -a "$LOG_FILE"
    else
        echo -e "$2 ... ${R}FAILURE${N}" | tee -a "$LOG_FILE"
        exit 1
    fi
}

# Disable nginx module if enabled
dnf module list nginx | grep -qE '^\s*nginx\s+[^\s]+\s+enabled'
if [ $? -eq 0 ]; then
    dnf module disable nginx -y >> "$LOG_FILE" 2>&1
    validate $? "Disabling nginx module"
else
    echo "nginx module already disabled" | tee -a "$LOG_FILE"
fi

# Enable nginx:1.24 if not already
dnf module list nginx:1.24 | grep -qE '^\s*nginx\s+1.24\s+enabled'
if [ $? -ne 0 ]; then
    dnf module enable nginx:1.24 -y >> "$LOG_FILE" 2>&1
    validate $? "Enabling nginx:1.24 module"
else
    echo "nginx:1.24 module already enabled" | tee -a "$LOG_FILE"
fi

# Install nginx if not installed
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

# Clean default web content
if [ "$(ls -A /usr/share/nginx/html 2>/dev/null)" ]; then
    rm -rf /usr/share/nginx/html/* >> "$LOG_FILE" 2>&1
    validate $? "Removing default nginx content"
else
    echo "No default content to remove" | tee -a "$LOG_FILE"
fi

# Download frontend content
if [ ! -f "$FRONTEND_ZIP" ]; then
    curl -s -o "$FRONTEND_ZIP" https://roboshop-artifacts.s3.amazonaws.com/frontend-v3.zip >> "$LOG_FILE" 2>&1
    validate $? "Downloading frontend zip"
else
    echo "Frontend zip already downloaded" | tee -a "$LOG_FILE"
fi

# Extract frontend content
cd /usr/share/nginx/html || exit 1
if [ ! -f index.html ]; then
    unzip "$FRONTEND_ZIP" >> "$LOG_FILE" 2>&1
    validate $? "Extracting frontend content"
else
    echo "Frontend content already extracted" | tee -a "$LOG_FILE"
fi

# Copy nginx.conf only if it exists in script directory
if [ -f "$SCRIPT_DIR/nginx.conf" ]; then
    if ! cmp -s "$SCRIPT_DIR/nginx.conf" /etc/nginx/nginx.conf; then
        cp "$SCRIPT_DIR/nginx.conf" /etc/nginx/nginx.conf >> "$LOG_FILE" 2>&1
        validate $? "Replacing nginx.conf with custom config"
    else
        echo "nginx.conf already up to date" | tee -a "$LOG_FILE"
    fi
else
    echo -e "${R}WARNING: nginx.conf not found in $SCRIPT_DIR. Skipping config step.${N}" | tee -a "$LOG_FILE"
fi

# Restart nginx
systemctl restart nginx >> "$LOG_FILE" 2>&1
validate $? "Restarting nginx to apply changes"

echo -e "${G}Frontend setup completed. Verify nginx on browser and update reverse proxy IPs in nginx.conf if needed.${N}" | tee -a "$LOG_FILE"
