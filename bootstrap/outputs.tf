output "terraform_state_bucket_name" {
  description = "The name of the S3 bucket storing the Terraform state."
  value       = aws_s3_bucket.terraform_state.bucket
}

output "state_arn" {
  description = "The ARN of the S3 bucket storing the Terraform state."
  value       = aws_s3_bucket.terraform_state.arn
}

output "terraform_lock_table_name" {
  description = "The name of the DynamoDB table used for state locking."
  value       = aws_dynamodb_table.terraform_lock.name
}

output "lock_arn" {
  description = "The ARN of the DynamoDB table used for state locking."
  value       = aws_dynamodb_table.terraform_lock.arn
}
