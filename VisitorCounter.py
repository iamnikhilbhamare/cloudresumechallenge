import json
import boto3

def lambda_handler(event, context):
    dynamodb = boto3.resource('dynamodb')
    
    table = dynamodb.Table('VisitorCount')
    
    
# get details from Dynamob
    response = table.get_item(
        Key={
            'total_visitors': 'visitors'
        }
        )
        
# Check if Count is present and increment it
    if 'Item' in response:
        if 'Count' in response['Item']:
            current_count = int(response['Item']['Count'])
        else:
            current_count = 0
        updated_count = current_count + 1
    else:
        updated_count = 1
        
    #return the updated_count value to Count attribute
    
    response = table.put_item(
        Item={
            'total_visitors': 'visitors',
            'Count': updated_count
        }
        )
    return response