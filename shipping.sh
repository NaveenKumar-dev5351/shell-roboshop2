#!/bin/bash

set -euo pipefail

START_TIME=$(date +%s)
USERID=$(id -u)
R="\e[31m"
G="\e[32m"
Y="\e[33m"
N="\e[0m"

LOGS_FOLDER="/var/log/Roboshop-logs"
SCRIPT_NAME=$(basename "$0" | cut -d "." -f1)
LOG_FILE="$LOGS_FOLDER/$SCRIPT_NAME.log"
SCRIPT_DIR="$PWD"

mkdir -p "$LOGS_FOLDER"
echo "script started executing at: $(date)" | tee -a "$LOG_FILE"

# Check for root privileges
if [ "$USERID" -ne 0 ]; then
    echo -e "$R ERROR:: please run this script with root access $N" | tee -a "$LOG_FILE"
    exit 1
else
    echo "You are running with root access" | tee -a "$LOG_FILE"
fi

# Ask for MySQL root password
echo "Please enter MySQL root password:"
read -s MYSQL_ROOT_PASSWORD

# Function to validate commands
VALIDATE() {
  if [ "$1" -eq 0 ]; then
    echo -e "$(date +%F' '%T) - $2 is ... ${G}SUCCESS${N}" | tee -a "$LOG_FILE"
  else 
    echo -e "$(date +%F' '%T) - $2 is ... ${R}FAILURE${N}" | tee -a "$LOG_FILE"
    exit 1
  fi
}

# Function to load MySQL schema
load_mysql_data() {
  echo "Loading data into MySQL..." | tee -a "$LOG_FILE"
  mysql -h mysql.devops84.store -u root -p"$MYSQL_ROOT_PASSWORD" < /app/db/schema.sql &>>"$LOG_FILE"
  mysql -h mysql.devops84.store -u root -p"$MYSQL_ROOT_PASSWORD" < /app/db/app-user.sql &>>"$LOG_FILE"
  mysql -h mysql.devops84.store -u root -p"$MYSQL_ROOT_PASSWORD" < /app/db/master-data.sql &>>"$LOG_FILE"
  VALIDATE $? "loading data into mysql"
}

# Install Maven
dnf install maven -y &>>"$LOG_FILE"
VALIDATE $? "Installing Maven and Java"

# Create roboshop user if not exists
if ! id roboshop &>/dev/null; then
    useradd --system --home /app --shell /sbin/nologin --comment "roboshop system user" roboshop &>>"$LOG_FILE"
    VALIDATE $? "Creating roboshop system user"
else
    echo -e "System user roboshop already created ... $Y skipping $N"
fi

# Create /app directory
mkdir -p /app 
VALIDATE $? "Creating /app directory"

# Download and unzip shipping app
curl -L -o /tmp/shipping.zip https://roboshop-artifacts.s3.amazonaws.com/shipping-v3.zip &>>"$LOG_FILE"
VALIDATE $? "Downloading shipping application"

rm -rf /app/*
cd /app 
unzip /tmp/shipping.zip &>>"$LOG_FILE"
VALIDATE $? "Unzipping shipping application"

# Build and move jar
mvn clean package &>>"$LOG_FILE"
VALIDATE $? "Packaging the shipping application"

mv target/shipping-1.0.jar shipping.jar &>>"$LOG_FILE"
VALIDATE $? "Renaming jar file to shipping.jar"

# Setup systemd service
cp "$SCRIPT_DIR/shipping.service" /etc/systemd/system/shipping.service
VALIDATE $? "Copying shipping.service to systemd"

systemctl daemon-reload &>>"$LOG_FILE"
VALIDATE $? "Systemd daemon-reload"

systemctl enable shipping &>>"$LOG_FILE"
VALIDATE $? "Enabling shipping service"

systemctl start shipping &>>"$LOG_FILE"
VALIDATE $? "Starting shipping service"

# Install MySQL client
dnf install mysql -y &>>"$LOG_FILE"
VALIDATE $? "Installing MySQL client"

# Check if cities table exists
mysql -h mysql.devops84.store -u root -p"$MYSQL_ROOT_PASSWORD" -e "USE cities; SHOW TABLES LIKE 'locations';" &>/dev/null
if [ $? -ne 0 ]; then
  load_mysql_data
else 
  echo -e "Data is already loaded into MySQL ... $Y skipping $N" | tee -a "$LOG_FILE"
fi

# Restart shipping service
systemctl restart shipping &>>"$LOG_FILE"
VALIDATE $? "Restarting shipping service"

# Final time calculation
END_TIME=$(date +%s)
TOTAL_TIME=$(( END_TIME - START_TIME ))

echo -e "Script execution completed successfully, $Y time taken: $TOTAL_TIME seconds $N" | tee -a "$LOG_FILE"
