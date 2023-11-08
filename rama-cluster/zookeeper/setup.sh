##!/bin/bash

sudo yum update -y

sudo cp zookeeper.service /etc/systemd/system
sudo systemctl start zookeeper.service
sudo systemctl enable zookeeper.service
