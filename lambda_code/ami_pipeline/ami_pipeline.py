import time

from pprint import pprint as pp

import boto3


def handler(event, context):
    pp(event)
    as_client = boto3.client('autoscaling')
    ec2_client = boto3.client('ec2')
    asg_client = boto3.client('autoscaling')

    response = as_client.describe_auto_scaling_groups(
        AutoScalingGroupNames=[event['autoScalingGroupName']],
        MaxRecords=1
    )

    launch_template_id = response['AutoScalingGroups'].pop()['LaunchTemplate']['LaunchTemplateId']

    response = ec2_client.describe_launch_template_versions(
        LaunchTemplateId=launch_template_id,
    )

    launch_template_data = [x for x in response['LaunchTemplateVersions'] if x['DefaultVersion'] == True].pop()['LaunchTemplateData']
    launch_template_data['ImageId'] = event['amiId']

    response = ec2_client.create_launch_template_version(
        LaunchTemplateId=launch_template_id,
        LaunchTemplateData=launch_template_data
    )

    template_version = response['LaunchTemplateVersion']['VersionNumber']

    response = ec2_client.modify_launch_template(
        LaunchTemplateId=launch_template_id,
        DefaultVersion=str(template_version)
    )


    asg = asg_client.describe_auto_scaling_groups(AutoScalingGroupNames=[event['autoScalingGroupName']])
    instances = asg['AutoScalingGroups'].pop()['Instances']

    for instance in instances:
        # terminate instace, this is bit naive approach
        # as we should check if replaced instance is healthy before terminating next one
        response = ec2_client.terminate_instances(
            InstanceIds=[instance['InstanceId']],
        )
        time.sleep(60)


#  EVENT = {
    #  "amiId": "ami-093121780b4daea6f",
    #  "autoScalingGroupName": "tf-asg-20190402104027109600000001"
#  }

#  handler(EVENT, None)
