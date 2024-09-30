#!/usr/bin/env bash

# Upload the rama.zip file to the /data/rama directory on the conductor
scp -o "StrictHostKeyChecking no" "$1" "$2@$3:/home/$2/rama.zip"
