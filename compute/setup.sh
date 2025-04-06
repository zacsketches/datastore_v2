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
sudo yum install -y golang git docker

####################
#  Mount Storage   #
####################
# Mount and format the persistent storage
echo "Mounting the persistent file system"
export DEVICE="/dev/xvdh"
export MOUNT_POINT="/mnt/readings"
export FSTAB_ENTRY="$DEVICE $MOUNT_POINT xfs defaults,nofail 0 2"
# GOPATH is required later go commands can store module data
export HOME=/home/ec2-user
export GOPATH=${HOME}/go
# Define the database file path
export DB=/mnt/readings/measurements.db
export SQL_DATA=$HOME/data.sql

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
mkdir -p "$MOUNT_POINT"
mount "$DEVICE" "$MOUNT_POINT"
# Add to /etc/fstab only if not already present
if ! grep -qs "$DEVICE" /etc/fstab; then
  echo "$FSTAB_ENTRY" >> /etc/fstab
  echo "Added mount to /etc/fstab"
else
  echo "Mount already exists in /etc/fstab, skipping."
fi

######################
#  Update user info  #
######################
# Update ec2-user's bash profile with a few aliases. Note that the webhook
# service is the last thing that gets set up. So, it might not be available
# yet when the instance is first logged into.
echo "Updating ec2-user's .bashrc"
echo "alias follow='journalctl -u webhook.service -f'" >> /home/ec2-user/.bashrc
echo "alias cloud-follow='sudo tail -f /var/log/cloud-init-output.log'" >> /home/ec2-user/.bashrc
echo "alias cloud-cat='sudo cat /var/log/cloud-init-output.log'" >> /home/ec2-user/.bashrc
echo "alias readings='sqlite3 -header -column $DB \"SELECT * FROM water_tests;\"'" >> /home/ec2-user/.bashrc
echo "alias load='sqlite3 DB < /home/ec2-user/data.csv'" >> /home/ec2-user/.bashrc

# sqlite> DELETE FROM water_tests;
# sqlite> VACUUM;
# sqlite> .exit

# Add the ec-user to the docker group so comms with the docker daemon work
sudo usermod -aG docker ec2-user
echo groups ec2-user

#################################
#  Install the graph container  #
#################################
# Start the docker daemon
sudo systemctl daemon-reload
sudo systemctl enable docker
sudo systemctl start docker

export AWS_REGION=$(aws ssm get-parameter --name "/ez-harbor/aws-region" --query "Parameter.Value" --output text --region us-east-1)
export AWS_ACCOUNT_ID=$(aws ssm get-parameter --name "/ez-harbor/aws-account-id" --query "Parameter.Value" --output text --region us-east-1)
export IMAGE=$(aws ssm get-parameter --name "/ez-harbor/graph-image" --query "Parameter.Value" --output text --region us-east-1)
export EIP=$(aws ssm get-parameter --name "/ez-harbor/elastic-ip" --query "Parameter.Value" --output text --region us-east-1)

aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com

docker pull $IMAGE
export READINGS_API=http://$EIP:8080/readings
echo "The READINGS_API is: $READINGS_API"
export IMAGE=$(docker image ls --format "{{.ID}}" | head -n 1)
docker run -d -e READINGS_API=$READINGS_API -p 8501:8501 $IMAGE
echo "graph container is running"

##############################
#  Install the SQL database  #
##############################
# Check if the database file exists
if [ -f "$DB" ]; then
    echo "Found database at $DB. Proceeding with chown..."
else
    echo "Database file $DB not found. Creating the file..."
    touch "$DB"
    echo "Database file $DB created."
fi

# Change ownership to ec2-user
chown ec2-user:ec2-user "$DB"
echo "Ownership of $DB has been set to ec2-user."

# Install SQLite if not available
echo "Checking if sqlite3 is installed..."
if ! command -v sqlite3 >/dev/null 2>&1; then
    echo "SQLite3 not found. Installing SQLite..."
    yum install -y sqlite
else
    echo "SQLite3 is already installed."
fi

# Create the measurements table if it does not already exist
echo "Creating the 'water_tests' table if it doesn't exist..."
sqlite3 "$DB" <<EOF
CREATE TABLE IF NOT EXISTS water_tests (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    testDate TEXT NOT NULL,
    chlorine REAL NOT NULL,
    ph REAL NOT NULL,
    acidDemand INTEGER,
    totalAlkalinity INTEGER
);
EOF

echo "Database setup and table creation completed."


###############################
#  Build the webhook service  #
###############################
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
Environment="READINGS_DB=$DB"

[Install]
WantedBy=multi-user.target
EOL
# Reload systemd, enable, and start the webhook.service
sudo systemctl daemon-reload
sudo systemctl enable webhook.service
sudo systemctl start webhook.service

#################
# sql data file #
#################
cat <<EOF > $SQL_DATA
INSERT INTO water_tests (testDate, chlorine, ph, acidDemand, totalAlkalinity) VALUES ('2025-04-01', 3.2, 7.4, 5, 12);
INSERT INTO water_tests (testDate, chlorine, ph, acidDemand, totalAlkalinity) VALUES ('2025-04-02', 3.0, 7.5, ROUND(5.5), ROUND(12.5));
INSERT INTO water_tests (testDate, chlorine, ph, acidDemand, totalAlkalinity) VALUES ('2025-04-03', 2.8, 7.6, 6, 13);
INSERT INTO water_tests (testDate, chlorine, ph, acidDemand, totalAlkalinity) VALUES ('2025-04-04', 3.5, 7.3, ROUND(4.5), 11);
INSERT INTO water_tests (testDate, chlorine, ph, acidDemand, totalAlkalinity) VALUES ('2025-04-05', 3.1, 7.4, 5, ROUND(11.5));
INSERT INTO water_tests (testDate, chlorine, ph, acidDemand, totalAlkalinity) VALUES ('2025-04-06', 3.0, 7.5, ROUND(5.2), ROUND(11.8));
INSERT INTO water_tests (testDate, chlorine, ph, acidDemand, totalAlkalinity) VALUES ('2025-04-07', 2.9, 7.6, ROUND(5.8), ROUND(12.2));
INSERT INTO water_tests (testDate, chlorine, ph, acidDemand, totalAlkalinity) VALUES ('2025-04-08', 3.3, 7.3, ROUND(4.8), ROUND(11.7));
INSERT INTO water_tests (testDate, chlorine, ph, acidDemand, totalAlkalinity) VALUES ('2025-04-09', 3.6, 7.5, ROUND(4.6), ROUND(12.4));
INSERT INTO water_tests (testDate, chlorine, ph, acidDemand, totalAlkalinity) VALUES ('2025-04-10', 2.7, 7.7, ROUND(6.3), ROUND(12.8));
INSERT INTO water_tests (testDate, chlorine, ph, acidDemand, totalAlkalinity) VALUES ('2025-04-11', 3.2, 7.4, 5, 12);
INSERT INTO water_tests (testDate, chlorine, ph, acidDemand, totalAlkalinity) VALUES ('2025-04-12', 3.0, 7.6, ROUND(5.7), 13);
INSERT INTO water_tests (testDate, chlorine, ph, acidDemand, totalAlkalinity) VALUES ('2025-04-13', 3.1, 7.3, ROUND(5.5), ROUND(11.5));
INSERT INTO water_tests (testDate, chlorine, ph, acidDemand, totalAlkalinity) VALUES ('2025-04-14', 3.5, 7.5, ROUND(5.2), ROUND(12.2));
INSERT INTO water_tests (testDate, chlorine, ph, acidDemand, totalAlkalinity) VALUES ('2025-04-15', 2.9, 7.4, 6, ROUND(12.5));
INSERT INTO water_tests (testDate, chlorine, ph, acidDemand, totalAlkalinity) VALUES ('2025-04-16', 3.2, 7.6, 5, ROUND(11.9));
INSERT INTO water_tests (testDate, chlorine, ph, acidDemand, totalAlkalinity) VALUES ('2025-04-17', 3.3, 7.5, ROUND(5.3), ROUND(12.1));
INSERT INTO water_tests (testDate, chlorine, ph, acidDemand, totalAlkalinity) VALUES ('2025-04-18', 3.4, 7.2, ROUND(4.7), ROUND(12.7));
INSERT INTO water_tests (testDate, chlorine, ph, acidDemand, totalAlkalinity) VALUES ('2025-04-19', 3.0, 7.7, ROUND(5.6), ROUND(12.3));
INSERT INTO water_tests (testDate, chlorine, ph, acidDemand, totalAlkalinity) VALUES ('2025-04-20', 2.8, 7.5, ROUND(6.2), 13);
EOF

echo "SQL commands have been written to $SQL_DATA."
