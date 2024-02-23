#!/bin/bash

sudo ${PACKAGE_MANAGER_COMMAND} update -y

echo "Downloading zookeeper..." >> setup.log

# Download and unpack Zookeeper
wget $1 -O zookeeper.tar.gz -o setup.log

# Extract zookeeper tar into a temporary directory
mkdir tmp && tar zxvf zookeeper.tar.gz -C tmp &>> setup.log

# Then move everything out of the top-level directory in tmp, into a zookeeper
# directory. Since we don't know the name of the file this is going to be, we
# can't just do a more straight fowards rename without isolating the file into
# it's own directory first.
mv tmp/* zookeeper
rm -rf tmp # then we clean up the now empty temporary directory

echo "Successfully downloaded Zookeeper" >> setup.log

mkdir zookeeper/data
mkdir zookeeper/logs