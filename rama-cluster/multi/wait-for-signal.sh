#!/bin/bash

echo "Waiting for disks to complete..."

# Wait for the signal file to appear
while [ ! -f "/tmp/disks_complete.signal" ]; do
    sleep 1
done

echo "Disks complete signal file detected, continuing with process..."
