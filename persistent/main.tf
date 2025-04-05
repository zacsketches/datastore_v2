terraform {
  required_version = ">= 1.0.0"
}

provider "aws" {
  region = "us-east-1"
}

terraform {
  backend "s3" {
    bucket         = "ezharbor-remote-tfstate"
    key            = "dev/persistent/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "ezharbor-tfstate-lock"
    encrypt        = true
  }
}

resource "aws_vpc" "ez_harbor_vpc" {
  cidr_block           = "172.31.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  instance_tenancy     = "default"

  tags = {
    Name = "ez-harbor-vpc"
  }

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_internet_gateway" "ez_harbor_igw" {
  vpc_id = aws_vpc.ez_harbor_vpc.id

  tags = {
    Name = "ez-harbor-igw"
  }

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_eip" "ez_harbor_webhook_eip" {
  vpc = true

  tags = {
    Name = "ez-harbor-webhook-eip"
  }

  lifecycle {
    prevent_destroy = true
  }
}

# Persistent storage for the SQLite database
resource "aws_ebs_volume" "readings_vol" {
  availability_zone = "us-east-1a"
  size              = 2 #Gb
  type              = "gp3" #affordable SSD storage approx $0.16 per month

  lifecycle {
    prevent_destroy = true
  }

  tags = {
    Name = "readings_vol"
  }
}

// Container registry for the streamlit container
resource "aws_ecr_repository" "chemistry_graph" {
  name = "chemistry-graph"

  image_tag_mutability = "IMMUTABLE"  # Change to MUTABLE if desired later
  image_scanning_configuration {
    scan_on_push = true
  }

  lifecycle {
    prevent_destroy = true
  }

  tags = {
    Name = "ez-harbor-registry"
  }
}

resource "aws_ssm_parameter" "aws_account_id" {
  name        = "/ez-harbor/aws-account-id"
  description = "AWS Account ID for ez-harbor infra"
  type        = "String"
  value       = var.aws_account_id
}

resource "aws_ssm_parameter" "aws_region" {
  name        = "/ez-harbor/aws-region"
  description = "AWS Account ID for ez-harbor infra"
  type        = "String"
  value       = var.aws_region
}
