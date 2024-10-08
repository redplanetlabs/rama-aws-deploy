#!/usr/bin/env bash


sudo yum update -y

echo "Starting zookeeper..."

sudo cp zookeeper.service /etc/systemd/system
sudo systemctl start zookeeper.service
sudo systemctl enable zookeeper.service

echo "Starting ZooKeeper status check loop..."

while true; do
    # Run the ZooKeeper status command and check its exit code
    if ./zookeeper/bin/zkServer.sh status > /dev/null 2>&1; then
        echo "ZooKeeper is running!"
        break
    else
        echo "ZooKeeper is not ready yet. Retrying..."
    fi
    sleep 1
done


# -f and sudo because we must override the rama.yaml that comes from extracting rama.zip
sudo mv -f /tmp/rama.yaml /data/rama/rama.yaml

cd /data/rama

sudo systemctl enable conductor.service
sudo systemctl start conductor.service

sudo systemctl enable supervisor.service
sudo systemctl start supervisor.service
