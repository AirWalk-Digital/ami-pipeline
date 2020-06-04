# AMI pipeline


## Overview
This repository provides an example of an AMI Pipeline using a set of Lambda functions and SSM automation, to create and deploy an AMI image in an ASG. It also contains configuartion for an example ASG for which a pipeline will be configured.

## Deployment

The framework can be deployed using Terraform 0.11.8. Before deployment, a number of pre-requisites must be met:

- A backend config file for your Terraform state must be configured in the `backend_config` directory
- An env vars file for your deployment must be configured in the `env_vars` directory

```bash
terraform init --backend-config ./backend_config/<config_file>.tf
terraform plan --var-file ./env_vars/<config_file>.tfvars --out ./build.plan
terraform apply ./build.plan

rm ./build.plan
```

## Pipeline

Pipeline is triggered by a CloudWatch rule scheduled to run daily, which invokes the Lambda function `ami_pipeline_trigger` whose responsibility is to assess if the AMI ID used in the launch template for a specific ASG is older than `n` days and if so to start the SSM automation `ami-pipeline` to build a new image.

SSM automations contains number of steps:

  - start instance with specific AMI ID
  - provision software on the instance using SSM run command
  - stop instance
  - create image from instance
  - terminate instance
  - invoke lambda function `ami_pipeline` to handle roll out of newly created AMI


`ami_pipeline` is responsible for updating the launch template with the newly created AMI ID Once that is done it will attempt roll it out across the ASG by terminating one instance at the time, which should be automatically re-launched by the ASG.

### Considerations

  - IAM policies should be revisited and narrowed down
  - Better way to roll out new AMI (1 instance at the time won't scale for larger ASGs)
  - Ideally AMIs should be built in separate subnet

