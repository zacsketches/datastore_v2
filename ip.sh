#!/bin/bash

# Notify user that the script is starting
echo "Starting export of Terraform webhook IP..."

# Get the output from Terraform
EIP=$(terraform output -raw webhook_ip)

# Export to parent shell by printing export command
export EIP=$EIP

# Confirm successful export
echo "Elastic IP (EIP) is set to: $EIP"
