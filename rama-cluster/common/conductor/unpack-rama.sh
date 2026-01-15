#!/usr/bin/env bash

cd /data/rama

sudo unzip -n rama.zip

# Get the rama.zip into the jar directory so supervisors can download it
local_dir=$(grep "local.dir" rama.yaml | cut -d ":" -f2 | xargs)

sudo mkdir -p "$local_dir/conductor/jars"
sudo cp rama.zip "$local_dir/conductor/jars"
