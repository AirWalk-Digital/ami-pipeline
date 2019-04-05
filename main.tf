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
    instance_profile     = "${aws_iam_instance_profile.instance_profile.arn}"
    assume_role = "${aws_iam_role.automation_role.arn}"
  }
}

resource "aws_ssm_document" "ami_pipeline" {
  name            = "ami-pipeline"
  document_type   = "Automation"
  document_format = "YAML"

  content = "${data.template_file.ssm_automation_document.rendered}"
}

resource "aws_launch_template" "launch_template" {
  name_prefix   = "launch-template"
  image_id      = "${var.base_ami_id}"
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

module "ami_pipeline_function_trigger" {
  source = "modules/automation_trigger"
  name   = "ami_pipeline_trigger"

  auto_scaling_group_name = "${aws_autoscaling_group.autoscaling_group.name}"
  base_ami_id = "${var.base_ami_id}"
  ami_age =  "${var.ami_age}"
  schedule_expression = "${var.schedule_expression}"
}

resource "aws_iam_instance_profile" "instance_profile" {
  name = "ami-pipeline-instance-profile"
  role = "${aws_iam_role.role.name}"
}

resource "aws_iam_role" "role" {
  name = "ami-pipeline-instance-role"
  path = "/"

  assume_role_policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Action": "sts:AssumeRole",
            "Principal": {
               "Service": "ec2.amazonaws.com"
            },
            "Effect": "Allow",
            "Sid": ""
        }
    ]
}
EOF
}

# ideally we shouldn't grant full access to ssm
resource "aws_iam_policy_attachment" "main" {
  name       = "ami-pipeline-instance-role"
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMFullAccess"
  roles      = ["${aws_iam_role.role.name}"]
}

resource "aws_iam_role" "automation_role" {
  name = "ami-pipeline-automation-role"
  path = "/"

  assume_role_policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Action": "sts:AssumeRole",
            "Principal": {
                "Service": [
                    "ec2.amazonaws.com",
                    "ssm.amazonaws.com"
                ]
            },
            "Effect": "Allow",
            "Sid": ""
        }
    ]
}
EOF
}

resource "aws_iam_policy" "automation_policy" {
  name = "ami-pipeline-automation-policy"

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "ec2:*",
                "iam:PassRole"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "lambda:InvokeFunction"
            ],
            "Resource": "${module.ami_pipeline_function.lambda_function["arn"]}"
        }
    ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "test-attach" {
  role       = "${aws_iam_role.automation_role.name}"
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonSSMAutomationRole"
}

resource "aws_iam_role_policy_attachment" "test-attach-1" {
  role       = "${aws_iam_role.automation_role.name}"
  policy_arn = "${aws_iam_policy.automation_policy.arn}"
}
