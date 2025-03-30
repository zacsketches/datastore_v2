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

  # depends_on = [aws_ebs_volume.sqlite_ebs]
}

# resource "aws_ebs_volume" "sqlite_ebs" {
#   availability_zone = "us-east-1a"  # Ensure this matches your instance's AZ
#   size              = 2  # 2GB EBS volume for our super small db
#   tags = {
#     Name = "sqlite-ebs-volume"
#   }
# }

# resource "aws_volume_attachment" "ebs_attach" {
#   device_name = "/dev/xvdf"
#   volume_id   = aws_ebs_volume.sqlite_ebs.id
#   instance_id = aws_instance.sqlite_ec2.id
# }

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

output "public_ip" {
  description = "The public IP address of the EC2 instance"
  value       = aws_instance.backend_ec2.public_ip
}

# output "users_api_url" {
#   description = "URL to access Flask API"
#   value       = "http://${aws_instance.sqlite_ec2.public_ip}:5000/users"
# }
