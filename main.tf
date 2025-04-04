provider "aws" {
  region = "us-east-1"
}

data "aws_ssm_parameter" "amzn2_latest" {
  name = "/aws/service/ami-amazon-linux-latest/amzn2-ami-hvm-x86_64-gp2"
}

resource "aws_instance" "backend_ec2" {
  availability_zone = "us-east-1a"  # Ensure this matches your instance's AZ
  ami           = data.aws_ssm_parameter.amzn2_latest.value
  instance_type = "t2.micro"
  key_name      = "my-key-pair"

  tags = {
    Name = "backend-instance-v2"
  }

  security_groups = [aws_security_group.allow_ssh.name]

  # Run the setup script
  user_data = file("setup.sh")

  # Attach EBS volume
  root_block_device {
    volume_size = 8  # Root volume (8GB)
  }
}

# Associate the EIP to the EC2 instance
resource "aws_eip_association" "backend_eip_assoc" {
  instance_id   = aws_instance.backend_ec2.id
  allocation_id = var.eip_allocation_id
}

# Set up security groups
resource "aws_security_group" "allow_ssh" {
  name        = "allow_ssh"
  description = "Allow SSH and webhook inbound traffic"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Change to your IP for security
  }

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Allows Flask API access
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# output "elastic_ip" {
#   description = "The Elastic IP address associated with the EC2 instance"
#   value       = aws_eip.backend_eip.public_ip
# }
output "webhook_ip" {
  description = "The public IP address of the EC2 instance"
  value       = aws_instance.backend_ec2.public_ip
}