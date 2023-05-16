import json
import boto3

def lambda_handler(event, context):
    # boto3 client
    client = boto3.client('s3')
    
    body = json.loads(event['Records'][0]['body'])
    message = json.loads(body["Message"])
    s3 = message['Records'][0]['s3']
    
    source_bucket_name = s3["bucket"]["name"]
    object_key = s3["object"]["key"]
    
    print(f"S3 bucket = {source_bucket_name}\nFile uploaded = {object_key}")
    
    # Retrieve the object
    response = client.get_object(Bucket=source_bucket_name, Key=object_key)
    
    # Get the contents of the object
    object_contents = response['Body'].read()
    
    print(f"response = {response}")
    print(f"object_contents = {object_contents}")
    
    
    # Specify the destination S3 bucket and object key
    destination_bucket_name = 'target-bucket-cloud-project'
    destination_object_key = 'teste_final.txt'
    
    # Upload the object to the destination bucket
    client.put_object(Body=object_contents, Bucket=destination_bucket_name, Key=destination_object_key)
    

    return {
        'statusCode': 200,
    }
