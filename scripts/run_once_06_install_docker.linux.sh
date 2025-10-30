#!/usr/bin/env bash
set -euo pipefail

sudo apt-get update
sudo apt-get install ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

# Add the repository to Apt sources:
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update

sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin -y

# fix docker user group issue
newgrp docker
sudo groupadd docker
sudo usermod -aG docker $USER
sudo chgrp docker /var/run/docker.sock

# change docker data root to raid0 mount if /data exists
if [ -d "/data" ]; then
  echo '{"data-root": "/data/docker"}' | sudo tee /etc/docker/daemon.json >/dev/null
  sudo systemctl restart docker
fi