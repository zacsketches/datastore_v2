terraform {
  backend "s3" {
    bucket         = "ezharbor-remote-tfstate" 
    key            = "dev/compute/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "ezharbor-tfstate-lock"
    encrypt        = true
  }
}

provider "aws" {
  region = "us-east-1"
}

data "terraform_remote_state" "remote" {
  backend = "s3"
  config = {
    bucket         = "ezharbor-remote-tfstate"
    key            = "dev/persistent/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "ezharbor-tfstate-lock"
    encrypt        = true
  }
}

resource "aws_eip_association" "webhook_association" {
  instance_id   = aws_instance.backend_ec2.id
  allocation_id = data.terraform_remote_state.remote.outputs.webhook_allocation_id
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

  security_groups = [aws_security_group.allow_ssh_and_8080.name]

  # Run the setup script
  user_data = file("setup.sh")

  # Attach EBS volume
  root_block_device {
    volume_size = 8  # Root volume (8GB)
  }
}

# Set up security groups tightly associated with THIS instance.
# Broad security groups for the environment belong in the persistent module.
resource "aws_security_group" "allow_ssh_and_8080" {
  name        = "allow_ssh_and_8080"
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

output "webhook_ip" {
  description = "The elastic IP associated with the EC2 instance"
  value = aws_eip_association.webhook_association.public_ip
}
