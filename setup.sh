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

# Ensure .bashrc exists for ec2-user
sudo -u ec2-user bash -c 'touch ~/.bashrc'

# Append environment variables to ec2-user's .bashrc
echo 'export PATH=$PATH:/usr/local/go/bin' | sudo tee -a /home/ec2-user/.bashrc
echo 'export GOPATH=$HOME/go' | sudo tee -a /home/ec2-user/.bashrc
echo 'export PATH=$PATH:$GOPATH/bin' | sudo tee -a /home/ec2-user/.bashrc

# Ensure the changes apply to new logins
chown ec2-user:ec2-user /home/ec2-user/.bashrc

# Clone your Go service repository
cd /home/ec2-user
sudo -u ec2-user git clone https://github.com/zacsketches/webhook-handler.git
# sudo chown ec2-user webhook-handler/
cd webhook-handler
go mod tidy
go build -o myapp
#sudo -u ec2-user bash -c 'export GO111MODULE=off && /usr/local/go/bin/go build -o myapp'

# Ensure the log file and hooks.txt file are writable
# touch /home/ec2-user/app.log
# chmod 666 /home/ec2-user/app.log
# touch /home/ec2-user/hooks.txt
# chmod 666 /home/ec2-user/hooks.txt

# Ensure the database directory exists
# mkdir -p /mnt/sqlite-data
# touch /mnt/sqlite-data/my_database.db

# Run the application as ec2-user
sudo -u ec2-user nohup ./myapp > /home/ec2-user/app.log 2>&1 &

# Open port 8080 for incoming HTTP traffic
sudo iptables -I INPUT -p tcp --dport 8080 -j ACCEPT
