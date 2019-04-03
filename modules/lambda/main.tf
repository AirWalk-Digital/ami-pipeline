data "aws_region" "current" {}

locals {
  iam_name = "${var.name}_lambda_security_rule"
}

resource "aws_lambda_function" "main" {
  function_name    = "${var.name}"
  filename         = "${data.archive_file.main.output_path}"
  source_code_hash = "${data.archive_file.main.output_base64sha256}"
  handler          = "${var.name}.handler"
  role             = "${aws_iam_role.main.arn}"
  timeout          = "600"
  runtime          = "python3.7"
}

data "archive_file" "main" {
  type        = "zip"
  source_dir  = "${local.code_path}"
  output_path = "${path.module}/${var.name}.zip"
}

resource "aws_iam_role" "main" {
  name = "${local.iam_name}_role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow"
    }
  ]
}
EOF
}

resource "aws_iam_policy" "main" {
  name = "${local.iam_name}_policy"

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "logs:CreateLogGroup",
                "logs:CreateLogStream",
                "logs:PutLogEvents"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "autoscaling:DescribeAutoScalingGroups",
                "ec2:DescribeLaunchTemplateVersions",
                "ec2:CreateLaunchTemplateVersion",
                "ec2:ModifyLaunchTemplate",
                "ec2:TerminateInstances"
            ],
            "Resource": "*"
        }
    ]
}
EOF
}

resource "aws_iam_policy_attachment" "main" {
  name       = "${local.iam_name}"
  policy_arn = "${aws_iam_policy.main.arn}"
  roles      = ["${aws_iam_role.main.name}"]
}

output "lambda_function" {
  value = {
    name = "${var.name}"
    arn  = "${aws_lambda_function.main.arn}"
  }
}
