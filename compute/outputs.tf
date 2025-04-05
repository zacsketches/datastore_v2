output "webhook_ip" {
  description = "The elastic IP associated with the EC2 instance"
  value = aws_eip_association.webhook_association.public_ip
}