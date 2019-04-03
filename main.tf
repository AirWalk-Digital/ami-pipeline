provider "aws" {
  region = "${var.primary_region}"
}

provider "aws" {
  region = "${var.primary_region}"
  alias  = "primary"
}

# provider "aws" {
# region = "${var.secondary_region}"
# alias  = "secondary"
# }

provider "archive" {
  version = "1.0.0"
}

terraform {
  backend "s3" {}
}

data "aws_caller_identity" "current" {}

data "aws_availability_zones" "available" {}

module "vpc" {
  source = "modules/vpc"
}

data "template_file" "ssm_automation_document" {
  template = "${file("automation.yaml")}"

  vars = {
    subnet               = "${module.vpc.private_subnet_ids[0]}"
    lambda_function_name = "${module.ami_pipeline_function.lambda_function["name"]}"
  }
}

resource "aws_ssm_document" "ami_pipeline" {
  name            = "ami-pipeline"
  document_type   = "Automation"
  document_format = "YAML"

  content = "${data.template_file.ssm_automation_document.rendered}"
}

resource "aws_launch_template" "launch_template" {
  name_prefix   = "foobar"
  image_id      = "ami-08d658f84a6d84a80"
  instance_type = "t2.micro"
}

resource "aws_autoscaling_group" "autoscaling_group" {
  availability_zones = ["${data.aws_availability_zones.available.names}"]
  desired_capacity   = 1
  max_size           = 1
  min_size           = 1

  launch_template {
    id      = "${aws_launch_template.launch_template.id}"
    version = "$$Latest"
  }
}

module "ami_pipeline_function" {
  source = "modules/lambda"
  name   = "ami_pipeline"
}
