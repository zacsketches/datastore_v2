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
