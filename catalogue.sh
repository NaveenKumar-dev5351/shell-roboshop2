#!/bin/bash

source ./common.sh
app_name=catalogue

check_root
app_setup
nodejs_setup
systemd_setup

cp $SCRIPT_DIR/mongo.repo /etc/yum.repos.d/mongo.repo
dnf install mongodb-mongosh -y &>>$LOG_FILE
VALIDATE $? "installing mongodb client"

STATUS=$(mongosh --quiet --host mongodb.devops84.store --eval 'db.getMongo().getDBNames().indexOf("catalogue")' 2>>"$LOG_FILE")

# Debug print (optional)
echo "DEBUG: STATUS='$STATUS'" | tee -a "$LOG_FILE"

# Validate STATUS is an integer
if ! [[ "$STATUS" =~ ^-?[0-9]+$ ]]; then
    echo -e "$R ERROR: Could not get valid status from MongoDB. STATUS='$STATUS' $N" | tee -a "$LOG_FILE"
    exit 1
fi

if [ "$STATUS" -lt 0 ]; then
    mongosh --host mongodb.devops84.store </app/db/master-data.js &>>"$LOG_FILE"
    VALIDATE $? "Loading data into mongodb"
else
    echo -e "Data is already loaded ... $Y skipping $N"
fi

print_time

