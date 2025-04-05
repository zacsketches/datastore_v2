
// Output the public IP address of the Elastic IP assigned to the webhook server
output "webhook_public_ip" {
  description = "The public IP of the ez-harbor webhook Elastic IP"
  value       = aws_eip.ez_harbor_webhook_eip.public_ip
}