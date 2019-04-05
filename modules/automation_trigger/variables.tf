variable "name" {}
variable "schedule_expression" {}
variable "auto_scaling_group_name" {}
variable "base_ami_id" {}
variable "ami_age" {}

locals {
  code_path = "./lambda_code/${var.name}"
}
