output "webhook_ip" {
  description = "The elastic IP associated with the EC2 instance"
  value = module.compute.webhook_ip
}