#!/bin/bash
# This script initializes an EC2 instance to host the backend webhook service.
# It installs dependencies, clones the repository, builds the service using Go modules,
# and sets up a systemd service to manage the webhook process.

# Exit immediately if a command exits with a non-zero status,
# treat unset variables as an error, print each command as it is executed,
# and propagate errors in pipelines.
set -euxo pipefail

# Update package index and install dependencies using yum
sudo yum update -y
sudo yum install -y golang git

# Mount and format the persistent storage
echo "Mounting the persistent file system"
DEVICE="/dev/xvdh"
MOUNT_POINT="/mnt/readings"
FSTAB_ENTRY="$DEVICE $MOUNT_POINT xfs defaults,nofail 0 2"
DB_DIR="$MOUNT_POINT/db"
DB_FILE="$DB_DIR/measurements.db"

# Wait for the device to be attached
while [ ! -b "$DEVICE" ]; do
  echo "Waiting for EBS volume to be available at $DEVICE..."
  sleep 5
done

# Create filesystem if one doesn't exist
if ! file -s "$DEVICE" | grep -q 'filesystem'; then
  echo "Creating filesystem on $DEVICE..."
  mkfs -t xfs "$DEVICE"
fi

# Create the mount point if it doesn't exist
mkdir -p "$MOUNT_POINT"

# Mount the volume
mount "$DEVICE" "$MOUNT_POINT"

# Add to /etc/fstab only if not already present
if ! grep -qs "$DEVICE" /etc/fstab; then
  echo "$FSTAB_ENTRY" >> /etc/fstab
  echo "Added mount to /etc/fstab"
else
  echo "Mount already exists in /etc/fstab, skipping."
fi

# Update ec2-user's bash profile with a few aliases. Note that the webhook
# service is the last thing that gets set up. So, it might not be available
# yet when the instance is first logged into.
echo "Updating ec2-user's .bashrc"
echo "alias follow='journalctl -u webhook.service -f'" >> /home/ec2-user/.bashrc
echo "alias cloud-follow='sudo tail -f /var/log/cloud-init-output.log'" >> /home/ec2-user/.bashrc
echo "alias cloud-cat='sudo cat /var/log/cloud-init-output.log'" >> /home/ec2-user/.bashrc
echo "alias readings='sqlite3 -header -column /mnt/readings/db/measurements.db \"SELECT * FROM water_tests;\"'" >> /home/ec2-user/.bashrc


# Create the SQLite database
mkdir -p "$DB_DIR"
chown ec2-user:ec2-user "$DB_DIR"

# Install SQLite if not available
command -v sqlite3 >/dev/null 2>&1 || yum install -y sqlite

# Create the measurements table if it does not already exist
sqlite3 "$DB_FILE" <<EOF
CREATE TABLE IF NOT EXISTS water_tests (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    testDate TEXT NOT NULL,
    chlorine REAL NOT NULL,
    ph REAL NOT NULL,
    acidDemand INTEGER,
    totalAlkalinity INTEGER
);
EOF


# GOPATH is required so later go commands can store module data
export HOME=/home/ec2-user
export GOPATH=${HOME}/go
echo $GOPATH

# Define variables
REPO_URL="https://github.com/zacsketches/webhook-handler.git"  # Replace with your repo URL
APP_DIR="/home/ec2-user/webhook-handler"  # Change as needed (default user for Amazon Linux 2 is ec2-user)
BINARY_NAME="webhook-service"

# Clone the repository if it doesn't exist; otherwise, update it
if [ ! -d "$APP_DIR" ]; then
    git clone "$REPO_URL" "$APP_DIR"
else
    cd "$APP_DIR"
    git pull
fi

cd "$APP_DIR"

# Build the service using Go modules
echo "Building the webhook service"
go build -o "$BINARY_NAME" .

# Move the binary to a directory in the system PATH
sudo mv "$BINARY_NAME" /usr/local/bin/

# Create a systemd service file for the webhook service
sudo tee /etc/systemd/system/webhook.service > /dev/null <<EOL
[Unit]
Description=Webhook Service
After=network.target

[Service]
ExecStart=/usr/local/bin/$BINARY_NAME
Restart=always
User=ec2-user
WorkingDirectory=$APP_DIR

[Install]
WantedBy=multi-user.target
EOL

# Reload systemd, enable, and start the webhook service
sudo systemctl daemon-reload
sudo systemctl enable webhook.service
sudo systemctl start webhook.service
