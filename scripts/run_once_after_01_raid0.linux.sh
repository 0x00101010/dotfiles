#!/usr/bin/env bash
set -euo pipefail

# Detect all NVMe drives excluding nvme0n1 (system partition)
NVME_DRIVES=($(ls /dev/nvme*n1 2>/dev/null | grep -v nvme0n1))
RAID_DEVICE_COUNT=${#NVME_DRIVES[@]}

if [ $RAID_DEVICE_COUNT -eq 0 ]; then
  echo "No additional NVMe drives found (excluding nvme0n1)"
  exit 1
fi

echo "Found $RAID_DEVICE_COUNT NVMe drive(s): ${NVME_DRIVES[@]}"
sudo mdadm --create --verbose /dev/md0 --level=0 --raid-devices=$RAID_DEVICE_COUNT ${NVME_DRIVES[@]} --force
sudo mkfs.ext4 /dev/md0

sudo mkdir -p /data
UUID=$(sudo blkid /dev/md0 | grep -oP 'UUID="\K[^"]+')
echo "UUID=$UUID /data ext4 defaults,nofail 0 0" | sudo tee -a /etc/fstab
sudo mount -a

sudo chown -R $USER:$USER /data
sudo chmod 755 /data