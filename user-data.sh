#!/bin/bash
set -eux

apt-get update
apt-get install -y docker.io

systemctl enable --now docker

until docker info >/dev/null 2>&1; do
  sleep 2
done

docker pull ldm2010/my-nginx-site:latest
docker rm -f my-nginx || true

docker run -d \
  --name my-nginx \
  --restart unless-stopped \
  -p 80:80 \
  ldm2010/my-nginx-site:latest