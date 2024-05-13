##!/bin/bash

sudo ${PACKAGE_MANAGER_COMMAND} update -y

echo "Starting zookeeper..." >> setup.log

sudo cp zookeeper.service /etc/systemd/system &>> setup.log
sudo systemctl start zookeeper.service &>> setup.log
sudo systemctl enable zookeeper.service &>> setup.log

# If Zookeeper successfully starts, we don't need this log anymore
rm setup.log