# variables.tf
variable "aws_account_id" {
  description = "The AWS Account ID to store in SSM"
  type        = string
}

variable "aws_region" {
  description = "The AWS region to store in SSM"
  type        = string
}