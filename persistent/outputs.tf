
// Output the public IP address of the Elastic IP assigned to the webhook server
output "webhook_public_ip" {
  description = "The public IP of the ez-harbor webhook Elastic IP"
  value       = aws_eip.ez_harbor_webhook_eip.public_ip
}

// Output the allocation id so we can use it to associate to an EC2 instance
output "webhook_allocation_id" {
  description = "The allocation ID of the ez-harbor webhook Elastic IP"
  value       = aws_eip.ez_harbor_webhook_eip.allocation_id
}