import json
import boto3
from PIL import Image

s3_client = boto3.client('s3')

def strip_exif(event, context):
    # Get the S3 bucket name and file key from the event
    bucket_name = event['Records'][0]['s3']['bucket']['name']
    file_key = event['Records'][0]['s3']['object']['key']

    s3_client.download_file(bucket_name, file_key, '/tmp/image.jpg')

    # Open the image file and remove the exif data
    with Image.open('/tmp/image.jpg') as img:
        img.save( '/tmp/image.jpg', "JPEG", exif=None)

    destination_bucket =  "bucket-b"

    ## Upload the modified image to the destination S3 bucket
    s3_client.upload_file('/tmp/image.jpg', destination_bucket, file_key)
