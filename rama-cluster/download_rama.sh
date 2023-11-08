#!/usr/bin/env bash

cd /data/rama

# TODO: get this from the conductor via scp 

curl --connect-timeout 180 'http://${conductor_ip}:8888/d/jar/download/rama.zip' \
     --output rama.zip

unzip rama.zip
