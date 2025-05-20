#!/bin/bash

# Define variables
USERID=$(id -u)
R="\e[31m"
G="\e[32m"
Y="\e[33m"
N="\e[0m"
LOGS_FOLDER="/var/log/roboshop-logs"
SCRIPT_NAME=$(echo $0 | cut -d"." -f1)
LOG_FILE="${LOGS_FOLDER}/${SCRIPT_NAME}.log"
SCRIPT_DIR=$PWD

# Create logs folder
mkdir -p "$LOGS_FOLDER"

# Check for root access
if [ "$USERID" -ne 0 ]; then
    echo -e "${R}ERROR: Please run this script with root access${N}" | tee -a "$LOG_FILE"
    exit 1
else
    echo "You are running with root access" | tee -a "$LOG_FILE"
fi

# Validate function
validate() {
    if [ "$1" -eq 0 ]; then
        echo -e "Installing $2 is ... ${G}SUCCESS${N}" | tee -a "$LOG_FILE"
    else
        echo -e "Installing $2 is ... ${R}FAILURE${N}" | tee -a "$LOG_FILE"
        exit 1
    fi
}

# Disable nodejs module
dnf module disable nodejs -y >> "$LOG_FILE"
validate $? "Disabling nodejs module"

# Enable nodejs:20 module
dnf module enable nodejs:20 -y >> "$LOG_FILE"
validate $? "Enabling nodejs module"

# Install nodejs
dnf install nodejs -y >> "$LOG_FILE"
validate $? "Installing nodejs"

# Create roboshop user
useradd --system --home /app --shell /sbin/nologin --comment "roboshop system user" roboshop >> "$LOG_FILE"
validate $? "Creating roboshop user"

# Create app directory
mkdir -p /app >> "$LOG_FILE"
cd /app

# Download catalogue.zip
curl -o /tmp/catalogue.zip https://roboshop-artifacts.s3.amazonaws.com/catalogue-v3.zip >> "$LOG_FILE"
validate $? "Downloading catalogue.zip"

# Unzip catalogue.zip
unzip /tmp/catalogue.zip >> "$LOG_FILE"
validate $? "Unzipping catalogue.zip"

# Install npm dependencies
npm install >> "$LOG_FILE"
validate $? "Installing dependencies & npm packages"

# Reload systemd daemon
systemctl daemon-reload >> "$LOG_FILE"
validate $? "Reloading systemd daemon"

# Copy catalogue.service file
cp $SCRIPT_DIR/catalogue.service /etc/systemd/system/catalogue.service >> "$LOG_FILE"
validate $? "Copying catalogue.service file"

# Reload systemd daemon
systemctl daemon-reload >> "$LOG_FILE"
validate $? "Reloading systemd daemon after copying service file"

# Enable and start catalogue service
systemctl enable catalogue >> "$LOG_FILE"
systemctl start catalogue >> "$LOG_FILE"
validate $? "Starting catalogue service"

# Copy mongo.repo
cp $SCRIPT_DIR/mongo.repo /etc/yum.repos.d/mongodb.repo >> "$LOG_FILE"
validate $? "Copying mongo.repo"

# Install mongodb-mongosh
dnf install mongodb-mongosh -y >> "$LOG_FILE"
validate $? "Installing mongodb-mongosh client"

# Load MongoDB schema
mongosh --host mongodb.daws86s.site < /app/db/master-data.js >> "$LOG_FILE"
validate $? "Loading MongoDB schema"
