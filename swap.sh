#!/bin/bash
set -e
echo "------------------------------"
echo "Unmounting the block storage..."
echo "------------------------------"

./unmount.sh

echo "------------------------------"
echo "Starting Terraform destroy..."
echo "------------------------------"

# Run terraform destroy
if terraform destroy -auto-approve; then
  echo "Terraform destroy completed successfully."
else
  echo "Error during terraform destroy. Exiting."
  exit 1
fi

echo "------------------------------"
echo "Starting Terraform apply..."
echo "------------------------------"

# Run terraform apply
if terraform apply -auto-approve; then
  echo "Terraform apply completed successfully."
else
  echo "Error during terraform apply. Exiting."
  exit 1
fi

echo "------------------------------"
echo "Terraform operations finished."
echo "------------------------------"
