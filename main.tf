terraform {
  required_version = ">= 1.0.0"

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

resource "aws_ssm_parameter" "aws_account_id" {
  name        = "/ez-harbor/aws-account-id"
  description = "AWS Account ID for ez-harbor infra"
  type        = "String"
  value       = var.aws_account_id
  overwrite   = true
}

module "compute" {
  source = "./compute"
  # Pass any module-specific variables here, e.g.:
  # instance_count = var.instance_count
}

