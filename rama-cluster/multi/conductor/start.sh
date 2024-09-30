#!/usr/bin/env bash

mv /run/rama/rama.yaml /data/rama/rama.yaml

cd /data/rama

systemctl enable conductor.service
systemctl start conductor.service
