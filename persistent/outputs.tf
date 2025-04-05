
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

// Output info needed to attach the volume to an instance
output "readings_vol_info" {
  description = "Details needed to attach the readings_vol EBS volume to an EC2 instance"
  value = {
    volume_id        = aws_ebs_volume.readings_vol.id
    availability_zone = aws_ebs_volume.readings_vol.availability_zone
    device_name      = "/dev/sdh"  # Standard Linux device name (adjust if needed)
  }
}

// Output of the Elastic Container Registry for the graph container
output "chemistry_graph_ecr_url" {
  description = "The URL for the Chemistry Graph ECR repository"
  value       = aws_ecr_repository.chemistry_graph.repository_url
}
