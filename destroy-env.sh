#!/bin/bash

sudo apt-get -y install ntpdate >> /dev/null
echo "Syncing client clock to amazon NTP servers"
sudo ntpdate 0.amazon.pool.ntp.org

# source - https://docs.aws.amazon.com/cli/latest/userguide/cli-usage-output.html

# Importing constants file into create-env.sh
. infrastructure_constants.sh

# Querying the autoscaling group to terminate
AUTOSCALE_GROUPS=`aws autoscaling describe-auto-scaling-groups --auto-scaling-group-name $AUTOSCALING_GROUP --query AutoScalingGroups[*][AutoScalingGroupName]`

echo "##############################################"
echo "#         Deleting AutoScaling Group         #"
echo "##############################################"
echo ""

# Iterate the autoscaling group only if AUTOSCALE_GROUPS exists. 
for asg in $AUTOSCALE_GROUPS;
do
    # Adjust the autoscale group scaling to 0 to allow termination.
    echo "Adjust the autoscale group minimum size to 0"
    aws autoscaling update-auto-scaling-group --auto-scaling-group-name $AUTOSCALING_GROUP --launch-configuration-name $LAUNCH_CONFIG --min-size 0 --max-size 1 --desired-capacity 0 

    INSTANCEIDS=`aws autoscaling describe-auto-scaling-instances --max-items 50 --query AutoScalingInstances[*].InstanceId`
    
    echo "##############################################"
    echo "# Terminating AutoScaling Group Instances    #"
    echo "##############################################"

    echo "Deleting AutoScaling Group"
    aws autoscaling delete-auto-scaling-group --auto-scaling-group-name $AUTOSCALING_GROUP --force-delete

    echo "Instances within AutoScaling group $INSTANCEIDS"
    # Iterate the instances in autoscaling group to destroy. 
    for instance in $INSTANCEIDS;
    do
        echo "Terminate EC2 instance with InstanceId: $instance";
        aws ec2 terminate-instances --instance-ids $instance;
        aws ec2 wait instance-terminated --instance-ids $instance;
    done;

    sleep 30
    # SCALING_ACTIVITIES=`aws autoscaling describe-scaling-activities --auto-scaling-group-name $AUTOSCALING_GROUP`
    # while [ ! -z "$SCALING_ACTIVITIES" ]
    # do
    #     echo "Polling till all scale down activities are completed and terminated."
    #     sleep 5
    #     SCALING_ACTIVITIES=`aws autoscaling describe-scaling-activities`
    # done

done;

LAUNCH_CONFIGURATIONS=`aws autoscaling describe-launch-configurations --launch-configuration-names $LAUNCH_CONFIG --query LaunchConfigurations[*][LaunchConfigurationName]`
echo "##############################################"
echo "#      Deleting Launch Configurations        #"
echo "##############################################"
echo ""
for lc in $LAUNCH_CONFIGURATIONS;
do
    echo "Deleting Launch Configuration: $LAUNCH_CONFIG"
    aws autoscaling delete-launch-configuration --launch-configuration-name $LAUNCH_CONFIG
done;

LOADBALANCERNAMES=$(aws elb describe-load-balancers --query 'LoadBalancerDescriptions[*].[LoadBalancerName]')

echo "##############################################"
echo "#         Deleting Load Balancers            #"
echo "##############################################"
echo ""
for elb in $LOADBALANCERNAMES;
do 
    if ( [ $elb == $ELB_NAME ] ); then
        echo "Deleting Load Balancer with Name: $elb";
        aws elb delete-load-balancer --load-balancer-name $elb
    fi
done;

echo "##############################################"
echo "#         Deleting Dynamodb                  #"
echo "##############################################"
echo ""
TABLE_NAMES=`aws dynamodb list-tables --query TableNames[*]`
for tbl_name in $TABLE_NAMES;
do 
    if ( [ $tbl_name == $DYNAMODB_TABLE_NAME ] ); then
        aws dynamodb delete-table --table-name $DYNAMODB_TABLE_NAME
        echo "Polling All DB Instance to be destroyed";
        aws dynamodb wait table-not-exists --table-name $DYNAMODB_TABLE_NAME
    fi
done;

echo "##############################################"
echo "#         Deleting SNS Topic                 #"
echo "##############################################"
echo ""
TOPIC_ARN=`aws sns list-topics --output json --query Topics[*].TopicArn | grep $TOPIC_NAME | tr -d '"'`

# https://forums.aws.amazon.com/thread.jspa?messageID=683913
for topic_arn in $TOPIC_ARN;
do 
    echo "Deleting SNS topic: $topic_arn";
    aws sns delete-topic --topic-arn $topic_arn
done;

echo "##############################################"
echo "#         Deleting Lambda Function           #"
echo "##############################################"
echo ""
LAMBDA_FUNCTIONS=`aws lambda list-functions --query Functions[*][FunctionName] | grep $LAMBDA_FUNCTION_NAME `
for lambda_fn in $LAMBDA_FUNCTIONS;
do aws lambda delete-function --function-name $LAMBDA_FUNCTION_NAME
done;

aws s3api put-bucket-notification-configuration --bucket $S3_RAW_BUCKET --notification-configuration {}

echo "##############################################"
echo "#         Infrastructure Terminated          #"
echo "##############################################"
