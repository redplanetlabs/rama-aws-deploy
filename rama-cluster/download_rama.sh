#!/usr/bin/env bash

cd /data/rama

# TODO: get this from the conductor via scp 

curl --connect-timeout 180 'http://${conductor_ip}:8888/d/jar/download/rama.zip' \
     --output rama.zip

until curl -s -f 'http://${conductor_ip}:8888/d/jar/download/rama.zip' \
           --output rama.zip
do
  echo "Failed to download rama.zip from the conductor. Retrying" \
       >> download.log
  sleep 5
done

unzip rama.zip

# Once we've successfully downloaded the zip we don't need this anymore.
# It's really just to make it clear that the supervisor is having trouble
# connecting to the conductor's web server.
rm download.log