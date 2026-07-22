#!/bin/bash
set -euxo pipefail

exec > >(tee /var/log/user-data.log | logger -t user-data -s 2>/dev/console) 2>&1
export DEBIAN_FRONTEND=noninteractive

apt-get update
apt-get install -y docker.io curl

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

curl -fsSL \
  https://amazoncloudwatch-agent.s3.amazonaws.com/ubuntu/amd64/latest/amazon-cloudwatch-agent.deb \
  -o /tmp/amazon-cloudwatch-agent.deb

dpkg -i -E /tmp/amazon-cloudwatch-agent.deb

cat > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json <<'CWAGENT_CONFIG'
${cloudwatch_agent_config}
CWAGENT_CONFIG

/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
  -a fetch-config \
  -m ec2 \
  -s \
  -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json