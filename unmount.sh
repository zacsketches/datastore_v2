#!/bin/bash

# Remote EBS unmount script via SSH

# === Configuration ===
export EIP=$(terraform output -raw webhook_ip)
EC2_USER="ec2-user"                          
EC2_HOST=$EIP                           
SSH_KEY="~/starlit_demo/datastore_v2/my-key-pair.pem"
DEVICE_NAME="/dev/xvdh"

# === Run the remote unmount ===
ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no "$EC2_USER@$EC2_HOST" bash -s <<EOF
  echo "Checking if $DEVICE_NAME is mounted..."
  MOUNT_POINT=\$(mount | grep "$DEVICE_NAME" | awk '{print \$3}')

  if [ -z "\$MOUNT_POINT" ]; then
    echo "No volume is mounted on $DEVICE_NAME. Nothing to do."
    exit 0
  fi

  echo "Shutting down webhook.service"
  sudo systemctl stop webhook.service

  echo "Unmounting $DEVICE_NAME from \$MOUNT_POINT..."
  sudo umount "$DEVICE_NAME"

  if [ \$? -eq 0 ]; then
    echo "Successfully unmounted $DEVICE_NAME."
  else
    echo "Failed to unmount $DEVICE_NAME. You may need to check for open files or processes."
    exit 1
  fi
EOF
