import json
import boto3
import markdown

def CloudConvertR(event, context):
    client = boto3.client('s3')
    
    body = json.loads(event['Records'][0]['body'])
    message = json.loads(body["Message"])
    s3 = message['Records'][0]['s3']
    
    # Source S3 bucket
    source_bucket_name = s3["bucket"]["name"]
    object_key = s3["object"]["key"]

    # Destination S3 bucket
    destination_bucket_name = 'output-bucket-cloudconvertr'
    destination_object_key = f"{object_key.split('.')[0]}.html"
    
    print(f"S3 bucket = {source_bucket_name}\nFile uploaded = {object_key}")
    
    # Reading de markdown file
    response = client.get_object(Bucket=source_bucket_name, Key=object_key)
    data = response['Body'].read()
    md = data.decode('utf-8')

    # Converting it to html
    html = markdown.markdown(md)
    
    # Storing the html file in the output bucket
    client.put_object(Body=html, Bucket=destination_bucket_name, Key=destination_object_key, ContentType='text/html')

    
    # Upload the object to the destination bucket
    # client.put_object(Body=html, Bucket=destination_bucket_name, Key=destination_object_key)
    

    return {
        'statusCode': 200,
    }