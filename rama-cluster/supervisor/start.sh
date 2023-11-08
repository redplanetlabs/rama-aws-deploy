#!/usr/bin/env bash

mv /run/rama/rama.yaml /data/rama/rama.yaml

PRIVATE_IP=$(curl http://169.254.169.254/latest/meta-data/local-ipv4)
PUBLIC_IP=$(curl http://169.254.169.254/latest/meta-data/public-ipv4)

cat <<EOF >> /data/rama/rama.yaml

supervisor.host:
  external: $PUBLIC_IP
  internal: $PRIVATE_IP
EOF

systemctl enable supervisor.service
systemctl start supervisor.service
