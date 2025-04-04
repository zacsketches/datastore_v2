# This variable is used in main.tf to associate the ec2 resource to an elastic ip.
# The value of the variable should be stored in a local copy of terraform.tfvars,
# that is .gitignore blocked from version control. The format for the required 
# terraform.tfvars file should follow the terraform.tfvars.example file that 
# IS INCLUDED in version control to provide a template for the real tfvars file 
# that needs to be held locally in the same directory as main.tf.
variable "eip_allocation_id" {
  description = "Elastic IP Allocation ID to associate with the backend ec2 instance"
  type        = string
}
