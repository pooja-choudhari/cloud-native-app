#!/bin/bash

if ( [ -z $1 ] || [ -z $2 ] || [ -z $3 ] || [ -z $4 ] || [ -z $5 ] || [ -z $6 ] || [ -z $7 ] || [ -z $8 ]); then
	echo "Missing one or more arguments:"
        echo "Usage: ./create-env.sh <ami-id> <count> <instance-type> <keypair-name> <security-group-ids> <ec2-iam-role-name> <subnet-id> <lambda-iam-role-arn>"
	exit 1
fi

echo "Syncing client clock to amazon NTP servers"
sudo apt-get -y install ntpdate >> /dev/null
sudo ntpdate 0.amazon.pool.ntp.org

# Importing constants file into create-env.sh
. infrastructure_constants.sh

echo "##############################################"
echo "#      Starting to setup Infrastructure      #"
echo "##############################################"

echo "##############################################"
echo "#         Dynamodb Database Creation         #"
echo "##############################################"

echo "Creating DynamoDB database: $DYNAMODB_TABLE_NAME"
aws dynamodb create-table --table-name $DYNAMODB_TABLE_NAME \
	--attribute-definitions AttributeName=Receipt,AttributeType=S AttributeName=Email,AttributeType=S \
	--key-schema AttributeName=Receipt,KeyType=HASH AttributeName=Email,KeyType=RANGE \
	--provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5

echo "Polling for Dynamodb table: $DYNAMODB_TABLE_NAME "
aws dynamodb wait table-exists --table-name $DYNAMODB_TABLE_NAME

echo ""
echo "##############################################"
echo "#             ELB Setup                      #"
echo "##############################################"

echo "Creating a load balancer"
ELB_DNS_URL=`aws elb create-load-balancer --load-balancer-name $ELB_NAME --listeners Protocol=HTTP,LoadBalancerPort=80,InstanceProtocol=HTTP,InstancePort=80 --subnets $7 --security-groups $5`

echo "Configuring Health Check for Load Balancer: $ELB_NAME"
aws elb configure-health-check --load-balancer-name $ELB_NAME \
	--health-check Target=HTTP:80/index.php,Interval=30,UnhealthyThreshold=2,HealthyThreshold=2,Timeout=3

echo "Creating Load Balancer Cookie Stickiness Policy"
aws elb create-lb-cookie-stickiness-policy --load-balancer-name $ELB_NAME \
	--policy-name lb-cookie-policy --cookie-expiration-period 60

echo "Attaching LB cookie policy to $ELB_DNS_URL"
aws elb set-load-balancer-policies-of-listener --load-balancer-name $ELB_NAME \
	--load-balancer-port 80 --policy-names lb-cookie-policy

echo ""
echo "##############################################"
echo "# Launch Configuration and AutoScaling Setup #"
echo "##############################################"

echo "Creating Launch Configuration"
aws autoscaling create-launch-configuration \
	--launch-configuration-name $LAUNCH_CONFIG \
	--key-name $4 \
	--image-id $1 \
	--instance-type $3 \
	--user-data file://install-app-env-front-end.sh \
	--security-groups $5 \
	--iam-instance-profile $6

echo "Creating Autoscaling group and attaching load balancer to the AWS autoscaling group"
aws autoscaling create-auto-scaling-group \
	--auto-scaling-group-name $AUTOSCALING_GROUP \
	--launch-configuration-name $LAUNCH_CONFIG \
	--min-size 2 --desired-capacity 3 --max-size 4 \
	--vpc-zone-identifier $7

echo "Attaching Load Balancer to Auto Scaling Group"
aws autoscaling attach-load-balancers --load-balancer-names $ELB_NAME --auto-scaling-group-name $AUTOSCALING_GROUP

# Image Processing using Lambda function and SNS notification
./install-app-env-back-end.sh $8

INSTANCEIDS=`aws autoscaling describe-auto-scaling-instances --max-items 50 --query AutoScalingInstances[*].InstanceId`

echo "Polling aws ec2 wait instance-running --instance-ids $INSTANCEIDS"
aws ec2 wait instance-running --instance-ids $INSTANCEIDS
echo "Instances running: $INSTANCEIDS"

echo ""
echo "#########################################################"
echo "# Wait: Autoscale Instances-in-Service with ELB         #"
echo "#########################################################"
echo "Polling EC2 instance to register with the load balancer"
aws elb wait instance-in-service --load-balancer-name $ELB_NAME --instances $INSTANCEIDS

echo "##############################################"
echo "#      End to setup Infrastructure           #"
echo "##############################################"
echo ""
echo "Application is available at $ELB_DNS_URL"
