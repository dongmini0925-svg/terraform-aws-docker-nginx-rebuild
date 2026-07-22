#!/bin/bash
set -eux

apt-get update
apt-get install -y docker.io

systemctl enable --now docker

docker run -d \
  --name my-nginx \
  --restart unless-stopped \
  -p 80:80 \
  nginx