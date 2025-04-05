#!/bin/bash

# Check if EIP environment variable is set
if [ -z "$EIP" ]; then
    echo "EIP is not set. Please export the EIP first."
    exit 1
fi

# Notify user about SSH connection initiation
echo "Connecting to server at $EIP..."

# SSH into the server using provided key
ssh -i my-key-pair.pem -o StrictHostKeyChecking=no ec2-user@$EIP
