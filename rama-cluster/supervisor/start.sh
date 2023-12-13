#!/usr/bin/env bash

mv /run/rama/rama.yaml /data/rama/rama.yaml

TOKEN=$(curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
PRIVATE_IP=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/local-ipv4)
PUBLIC_IP=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/public-ipv4)

cat <<EOF >> /data/rama/rama.yaml

supervisor.host:
  external: "$PUBLIC_IP"
  internal: "$PRIVATE_IP"
EOF

systemctl enable supervisor.service
systemctl start supervisor.service
