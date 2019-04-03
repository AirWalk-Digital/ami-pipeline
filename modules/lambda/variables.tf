variable "name" {}

locals {
  code_path = "./lambda_code/${var.name}"
}
