#!/bin/bash

echo "Installing Uni-Sync-Timer"
echo "remember that his needs the uni-sync found at https://github.com/EightB1ts/uni-sync please install that"
echo "the script also needs the following package to work: bc and jq"

cp uni-sync-timer.sh /bin/uni-sync-timer
chmod +x /bin/uni-sync-timer

echo ""
echo "Installing Example Profile for Uni-Sync-Timer remember to change the profile"
echo "to have the correct sensor driver and sensor name, this can be found with sensors command"
echo "and with looking example driver: k10temp sensor: Tctl" 

cp uni-sync_profile.json /etc/uni-sync/uni-sync_profile.json

echo ""
echo "Installing Systemd Service enable to enable this type systemctl enable uni-sync-timer.service"

cp uni-sync-timer.service /etc/systemd/system/uni-sync-timer.service