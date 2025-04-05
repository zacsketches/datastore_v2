data "terraform_remote_state" "persistent" {
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
  allocation_id = data.terraform_remote_state.persistent.outputs.webhook_allocation_id
}

data "aws_ssm_parameter" "amzn2_latest" {
  name = "/aws/service/ami-amazon-linux-latest/amzn2-ami-hvm-x86_64-gp2"
}

#######################
# Set up EC2 IAM      #
#######################

# 1. Define the IAM Role with EC2 trust policy
resource "aws_iam_role" "backend_ec2_role" {
  name = "backend-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action    = "sts:AssumeRole",
        Effect    = "Allow",
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

# 2. Attach an inline policy for ECR access to the role
resource "aws_iam_role_policy" "backend_ec2_role_ecr" {
  name = "backend-ec2-ecr-access"
  role = aws_iam_role.backend_ec2_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage"
        ],
        Resource = "*"
      }
    ]
  })
}

# 3. Create the profile that is associated tothe role
resource "aws_iam_instance_profile" "backend_ec2_profile" {
  name = "backend-ec2-profile"
  role = aws_iam_role.backend_ec2_role.name
}


resource "aws_instance" "backend_ec2" {
  availability_zone = "us-east-1a"
  ami           = data.aws_ssm_parameter.amzn2_latest.value
  instance_type = "t2.micro"
  key_name      = "my-key-pair"

  # 4. Finally, associate the profile with this instance
  iam_instance_profile = aws_iam_instance_profile.backend_ec2_profile.name

  tags = {
    Name = "backend-instance-v2"
  }

  security_groups = [aws_security_group.allow_ssh_and_8080.name]

  # Run the setup script
  user_data = file("compute/setup.sh")

  # Attach EBS volume
  root_block_device {
    volume_size = 8  # Root volume (8GB)

    tags = {
      Name = "webhook-root-vol"
    }
  }
}

# Attach the persistent volume to the ec2 instance
resource "aws_volume_attachment" "attach_readings_vol" {
  device_name = data.terraform_remote_state.persistent.outputs.readings_vol_info.device_name
  volume_id   = data.terraform_remote_state.persistent.outputs.readings_vol_info.volume_id
  instance_id = aws_instance.backend_ec2.id

  force_detach = false

  # Also hoping this helps a little
  depends_on = [
    aws_instance.backend_ec2
  ]

  # This can help since the device name is changed when it is mounted inside the volume
  lifecycle {
    ignore_changes = [device_name]
  }
}

# Set up security groups tightly associated with THIS instance.
resource "aws_security_group" "allow_streamlit" {
  name        = "allow_streamlit"
  description = "Allow Streamlit app inbound traffic"

  ingress {
    from_port   = 8501
    to_port     = 8501
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Allows access to the Streamlit app; restrict if needed
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

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
