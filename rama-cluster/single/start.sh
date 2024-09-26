#!/usr/bin/env bash

mv /run/rama/rama.yaml /data/rama/rama.yaml


sudo yum update -y

echo "Starting zookeeper..." >> setup.log

sudo cp zookeeper.service /etc/systemd/system &>> setup.log
sudo systemctl start zookeeper.service &>> setup.log
sudo systemctl enable zookeeper.service &>> setup.log

# If Zookeeper successfully starts, we don't need this log anymore
rm setup.log


cd /data/rama

systemctl enable conductor.service
systemctl start conductor.service

systemctl enable supervisor.service
systemctl start supervisor.service
