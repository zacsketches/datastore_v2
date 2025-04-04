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

# Enable Go modules (Go 1.16+ has modules enabled by default, but this ensures it)
export GO111MODULE=on

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
