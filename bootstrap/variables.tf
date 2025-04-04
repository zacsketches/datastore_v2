variable "region" {
  description = "The AWS region where resources will be deployed."
  type        = string
  default     = "us-east-1"
}

variable "bucket_name" {
  description = "The name of the S3 bucket to store Terraform state."
  type        = string
}

variable "dynamodb_table_name" {
  description = "The name of the DynamoDB table used for state locking."
  type        = string
}
