#!/bin/bash

source ./common.sh
app_name=shipping

check_root

echo "please enter root password to setup"
read -s MYSQL_ROOT_PASSWORD

app_setup
maven_setup
systemd_setup

dnf install mysql -y &>>$LOG_FILE
VALIDATE $? "Install mysql"

mysql -h mysql.devops84.store -u root -p$MYSQL_ROOT_PASSWORD -e 'use cities' &>>$LOG_FILE
if [ $? -ne 0 ]
then
  mysql -h mysql.devops84.store -uroot -p$MYSQL_ROOT_PASSWORD < /app/db/schema.sql &>>$LOG_FILE
  mysql -h mysql.devops84.store -uroot -p$MYSQL_ROOT_PASSWORD < /app/db/app-user.sql &>>$LOG_FILE
  mysql -h mysql.devops84.store -uroot -p$MYSQL_ROOT_PASSWORD < /app/db/master-data.sql &>>$LOG_FILE
  VALIDATE $? "loading data into mysql"
else 
  echo -e "Data is already loaded into mysql ... $Y skipping $N"
fi

systemctl restart shipping &>>$LOG_FILE
VALIDATE $? "restart shipping"

print_time