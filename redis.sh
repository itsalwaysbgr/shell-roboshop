#!/bin/bash

USERID=$(id -u)
R="\e[31m"
G="\e[32m"
Y="\e[33m"
N="\e[0m"
START_TIME=$(date +%s)

LOGS_FOLDER="/var/log/roboshop-logs"
SCRIPT_NAME=$(echo $0 | cut -d"." -f1)
LOG_FILE="${LOGS_FOLDER}/${SCRIPT_NAME}.log"

mkdir -p "$LOGS_FOLDER"
echo "Script started executing at: $(date)" | tee -a "$LOG_FILE"

VALIDATE(){
    if [ $1 -eq 0 ]; then
        echo -e "$2 is ... $G SUCCESS $N" | tee -a "$LOG_FILE"
    else
        echo -e "$2 is ... $R FAILURE $N" | tee -a "$LOG_FILE"
        exit 1
    fi
}

dnf module disable redis -y &>>"$LOG_FILE"
VALIDATE $? "Disabling default redis"

dnf module enable redis:7 -y &>>"$LOG_FILE"
VALIDATE $? "Enabling redis:7"

dnf install redis -y &>>"$LOG_FILE"
VALIDATE $? "Installing redis"

sed -i -e 's/127.0.0.1/0.0.0.0/g' -e '/^protected-mode/ c protected-mode no' /etc/redis/redis.conf
VALIDATE $? "Editing /etc/redis/redis.conf file for remote connections"

systemctl enable redis &>>"$LOG_FILE"
VALIDATE $? "Enabling redis service"

systemctl start redis &>>"$LOG_FILE"
VALIDATE $? "Starting redis service"

END_TIME=$(date +%s)
DIFF_TIME=$((END_TIME - START_TIME))
echo "Script execution time: $((DIFF_TIME / 60)) minutes and $((DIFF_TIME % 60)) seconds" | tee -a "$LOG_FILE"
echo "Script started at: $(date)" | tee -a "$LOG_FILE"
echo "Script completed at: $(date)" | tee -a "$LOG_FILE"
echo -e "$G Redis installation completed successfully $N" | tee -a "$LOG_FILE"
