import datetime
import time

import boto3


def handler(event, context):
    as_client = boto3.client('autoscaling')
    ec2_client = boto3.client('ec2')
    asg_client = boto3.client('autoscaling')
    ssm_client = boto3.client('ssm')

    response = as_client.describe_auto_scaling_groups(
        AutoScalingGroupNames=[event['autoScalingGroupName']],
        MaxRecords=1
    )

    group = response['AutoScalingGroups'].pop()
    launch_template_id = group['LaunchTemplate']['LaunchTemplateId']
    launch_template_version = group['LaunchTemplate']['Version']

    launch_template_versions = ec2_client.describe_launch_template_versions(
        LaunchTemplateId=launch_template_id,
        Versions=[launch_template_version]
    )['LaunchTemplateVersions']

    ami_id = launch_template_versions.pop()['LaunchTemplateData']['ImageId']

    ec2 = boto3.resource('ec2')
    image = ec2.Image(ami_id)

    creation_date = datetime.datetime.fromisoformat(image.creation_date.replace('Z', ''))
    current_date = datetime.datetime.now()
    delta_days = (current_date - creation_date).days

    if delta_days >= int(event['amiAge']):
        # trigger ssm automation to build new image and replace instances with new based on it

        response = ssm_client.start_automation_execution(
            DocumentName='ami-pipeline',
            Parameters={
                'autoScalingGroupName': [event['autoScalingGroupName']],
                'baseAmiId': [event['baseAmiId']],
            },
            Mode='Auto'
        )
