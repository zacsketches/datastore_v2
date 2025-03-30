#!/bin/bash

# Sets debug mode for verbose output and exits on any error
set -ex

# Install required dependencies
sudo yum update -y
sudo yum install -y git wget unzip sqlite

# Install Go
GO_VERSION="1.21.1"
wget "https://go.dev/dl/go${GO_VERSION}.linux-amd64.tar.gz"
sudo tar -C /usr/local -xzf "go${GO_VERSION}.linux-amd64.tar.gz"
echo 'export PATH=$PATH:/usr/local/go/bin' >> ~/.bashrc
echo 'export GOPATH=$HOME/go' >> ~/.bashrc
echo 'export PATH=$PATH:$GOPATH/bin' >> ~/.bashrc
source ~/.bashrc

# Clone your Go service repository
cd /home/ec2-user
git clone https://github.com/zacsketches/webhook-handler.git
cd webhook-handler

# Build the Go application
/usr/local/go/bin/go build -o myapp

# Ensure the database directory exists
mkdir -p /mnt/sqlite-data
touch /mnt/sqlite-data/my_database.db

# Run the application in the background
nohup ./myapp > app.log 2>&1 &

# Open port 5000 for incoming HTTP traffic
sudo iptables -I INPUT -p tcp --dport 5000 -j ACCEPT
