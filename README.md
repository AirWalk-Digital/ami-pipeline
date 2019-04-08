# AMI pipeline


## Overview
This repository provides example of AMI Pipeline using set of Lambda functions and SSM automation, to create and deploy AMI image in ASG. It also contains configuartion for example ASG for which pipeline will be configured.

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

Pipeline is triggered by CloudWatch rule scheduled to run daily, which invokes lambda function `ami_pipeline_trigger` which responsibility is to assess if AMI id used in launch template for specific ASG is older than `n` days and if so to start SSM automation `ami-pipeline` to build new image.

SSM automations contains number of steps:

  - start instance with specific AMI ID
  - provision software on the instance using SSM run command
  - stop instance
  - create image from instance
  - terminate instance
  - invoke lambda function `ami_pipeline` to handle roll out of newly created AMI


`ami_pipeline` is responsible for updating launch template with newly created AMI Id, once that is done it will attempt roll out it across ASG by terminating one instance at the time, which should be automatically re launched by ASG.

### Considerations

  - IAM policies should be revisited and narrowed down
  - Better we to roll out new AMI (1 instance at the time won't scale for larger ASGs)
  - Ideally AMIs should be build in separate subnet

