#!/usr/bin/env bash

# This is intended to be run as root - user data scripts are run as such automatically

yum -y install nvme-cli

DEVICE=`nvme list | grep "Instance Storage" | awk '{print $1}'`

mkdir -p /data

if [ ! -z $DEVICE ] ; then
  mkfs.ext4 "$DEVICE"
  echo "$DEVICE /data ext4 defaults 0 0" | tee -a /etc/fstab
  mount /data
fi

USERNAME='${username}'
if [ "$USERNAME" = '${username}' ]; then 
  USERNAME="$1"
fi

mkdir -p /data/rama/license
chown -R "$USERNAME:$USERNAME" /data/

fallocate -l 10G /swapfile
chmod 600 /swapfile
mkswap /swapfile
swapon /swapfile
echo '/swapfile none swap sw 0 0' | tee -a /etc/fstab
echo 'vm.swappiness=0' | tee -a /etc/sysctl.conf

# to signal that disk process is done, so conductor provisioners can proceed
touch /tmp/disks_complete.signal
