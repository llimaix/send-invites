#!/bin/bash
# Primer arranque: instala Docker Engine y el plugin Compose desde el
# repositorio oficial de Docker para Ubuntu (https://docs.docker.com/engine/install/ubuntu/).
set -euxo pipefail

export DEBIAN_FRONTEND=noninteractive

timedatectl set-timezone America/Guatemala

apt-get update
apt-get install -y ca-certificates curl git

install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc

echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" \
  > /etc/apt/sources.list.d/docker.list

apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

systemctl enable --now docker

# Permite a "ubuntu" usar docker sin sudo. Ojo: el grupo docker equivale a root.
usermod -aG docker ubuntu

# Swap de 2 GiB como colchón de memoria (Chatwoot + n8n + Evolution).
if [ ! -f /swapfile ]; then
  fallocate -l 2G /swapfile
  chmod 600 /swapfile
  mkswap /swapfile
  swapon /swapfile
  echo '/swapfile none swap sw 0 0' >> /etc/fstab
fi
