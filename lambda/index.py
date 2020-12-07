import os
import logging
import boto3

LOGGER = logging.getLogger()
LOGGER.setLevel(logging.INFO)

DST_BUCKET = os.environ.get('DST_BUCKET')
REGION = os.environ.get('REGION')

s3_client = boto3.client("s3")
dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table('information')

def handler(event, context):
   LOGGER.info('Event structure: %s', event)
   LOGGER.info('DST_BUCKET: %s', DST_BUCKET)

   bucket_name = event['Records'][0]['s3']['bucket']['name']
   s3_file_name = event['Records'][0]['s3']['object']['key']
   resp = s3_client.get_object(Bucket=bucket_name, Key=s3_file_name)
   data = resp['Body'].read().decode("utf-8")

   information = data.split("\n")

   for info in information:
       print(info)
       info_req = info.split(",")
       try:
           table.put_item(
               Item = {
                   "id" : info_req[0],
                   "city" : info_req[1],
                   "position" : info_req[2]
               }
           )
       except Exception as e:
           print("End of file")