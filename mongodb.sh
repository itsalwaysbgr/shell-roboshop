#!/bin/bash

USERID=$(id -u)
R="\e[31m"
G="\e[32m"
Y="\e[33m"
N="\e[0m"
LOGS_FOLDER="/var/log/roboshop-logs"
SCRIPT_NAME=$(echo $0 | cut -d"." -f1)
LOG_FILE="${LOGS_FOLDER}/${SCRIPT_NAME}.log"


mkdir -p "$LOGS_FOLDER"

if [ "$USERID" -ne 0 ]; then
    echo -e "${R}ERROR: Please run this script with root access${N}" | tee -a "$LOG_FILE"
    exit 1
else
    echo "You are running with root access" | tee -a "$LOG_FILE"
fi

# Validate function: takes exit status and command name
validate() {
    if [ "$1" -eq 0 ]; then
        echo -e "Installing $2 is ... ${G}SUCCESS${N}" | tee -a "$LOG_FILE"
    else
        echo -e "Installing $2 is ... ${R}FAILURE${N}" | tee -a "$LOG_FILE"
        exit 1
    fi
}
cp mongo.repo /etc/yum.repos.d/mongodb.repo
VALIDATE $? "Copying mongodb.repo file"

dnf install mongodb-org -y >> "$LOG_FILE"
VALIDATE $? "Installing mongodb-org"

systemctl enable mongod >> "$LOG_FILE"
VALIDATE $? "Enabling mongod service"

# Start the MongoDB service
systemctl start mongod >> "$LOG_FILE"
VALIDATE $? "Starting mongod service"

sed -i -e 's/127.0.0.1/0.0.0.0/g' /etc/mongod.conf
VALIDATE $? "Editing /etc/mongod.conf file for remote connections"

systemctl restart mongod >> "$LOG_FILE"
VALIDATE $? "Restarting mongod service"