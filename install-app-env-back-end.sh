#!/bin/bash

if ( [ -z $1 ] ); then
	echo "Missing lambda role arn"
        echo "Usage: ./install-app-env-back-end.sh <lambda-iam-role-arn>"
	exit 1
fi

# Importing constants file into install-app-env-back-end.sh
. infrastructure_constants.sh

echo ""
echo "##############################################"
echo "#          Setting up SNS Topic              #"
echo "##############################################"

aws sns create-topic --name $TOPIC_NAME

echo ""
echo "##############################################"
echo "#        Creating Lambda Function            #"
echo "##############################################"

aws lambda create-function --function-name $LAMBDA_FUNCTION_NAME \
	--runtime python3.6 --zip-file fileb://lambdaFn/lambdaFn.zip \
	--timeout 20 \
	--handler process.handler --role $1

aws lambda add-permission --function-name $LAMBDA_FUNCTION_NAME --action lambda:InvokeFunction \
	--principal s3.amazonaws.com --source-arn arn:aws:s3:::$S3_RAW_BUCKET --statement-id 1

LAMBDA_FN_ARN=`aws lambda get-function --function-name $LAMBDA_FUNCTION_NAME --query Configuration.FunctionArn`

aws s3api put-bucket-notification-configuration --bucket $S3_RAW_BUCKET --notification-configuration '{ "LambdaFunctionConfigurations": [ { "LambdaFunctionArn": "'$LAMBDA_FN_ARN'", "Events": ["s3:ObjectCreated:*"] } ] }'
