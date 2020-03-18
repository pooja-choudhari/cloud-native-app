import boto3
import os
import sys
import uuid
from urllib.parse import unquote_plus
from PIL import Image
import PIL.Image
import logging
import hashlib
import logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)
import base64

s3_client = boto3.client('s3')
dynamo_client = boto3.client('dynamodb')
sns_client = boto3.client('sns')

def resize_image(image_path, resized_path):
    with Image.open(image_path) as image:
        logging.info('Image Size: {}'.format(image.size))
        MAX_SIZE = (100, 100)
        image.thumbnail(MAX_SIZE)
        image.save(resized_path)

def handler(event, context):
    for record in event['Records']:
        bucket = record['s3']['bucket']['name']
        key = unquote_plus(record['s3']['object']['key'])
        logger.info('Unquote Key: {}'.format(record['s3']['object']['key']))

        extension = key.split('.')[-1]  # Split to get filename for extension
        useremail = key.split('/')[0]   # Split to get useremail from key
        extension_to_use = extension if extension in ['jpg', 'JPG', 'jpeg', 'JPEG', 'png', 'PNG'] else ''

        head_resp = s3_client.head_object(Bucket=bucket, Key=key)
        receipt = head_resp['Metadata']['receipt']
        unique_key = '{}.{}'.format(receipt, extension_to_use)

        download_path = '/tmp/{}'.format(unique_key)
        upload_path = '/tmp/resized-{}'.format(unique_key)

        logger.info('Starting to resize image at {}'.format(download_path))
        s3_client.download_file(bucket, key, download_path)
        resize_image(download_path, upload_path)
        s3_client.upload_file(upload_path, '{}resized'.format(bucket), key, ExtraArgs={'ACL': 'public-read'})

        finished_url = 'https://{}resized.s3.amazonaws.com/{}'.format(bucket, key)
        logger.info('Resized image at {} uploaded to S3'.format(upload_path))        

        db_resp = dynamo_client.update_item(
            TableName='Records-cpooja',
            Key={
                'Receipt': {'S': receipt},
                'Email': {'S': useremail}
                },
            UpdateExpression="set S3finishedurl=:processed_url, #processed = :processed",
            ExpressionAttributeValues={
                ':processed_url': {'S': finished_url},
                ':processed': {'BOOL': True}
                },
            ExpressionAttributeNames={"#processed": "Status"},
            ReturnValues="ALL_NEW"
            )

        userphone = db_resp['Attributes']['Phone']['S']

        # Finding topic to publish message
        topic_arn = None
        response = sns_client.list_topics()
        for topic in response['Topics']:
            if 'cpooja' in topic['TopicArn']:
                topic_arn = topic['TopicArn']

        # Subscribing to Topic Found above

        sub_response = sns_client.subscribe(
            TopicArn=topic_arn,
            Protocol='sms',
            Endpoint=userphone)

        pub_resp = sns_client.publish(
            PhoneNumber=userphone,
            Message='Your photo has been processed successfully and available at URL: {}'.format(finished_url))
