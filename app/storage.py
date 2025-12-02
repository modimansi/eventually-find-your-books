import os
import boto3
from typing import List, Dict
from app.config import settings

# Use local DynamoDB endpoint in debug mode
LOCAL_ENDPOINT = "http://dynamodb:8000"

if settings.debug:
    dynamodb = boto3.resource("dynamodb", region_name=settings.aws_region, endpoint_url=LOCAL_ENDPOINT)
else:
    dynamodb = boto3.resource("dynamodb", region_name=settings.aws_region)

table = dynamodb.Table(settings.dynamodb_table_ratings)

def fetch_all_ratings() -> List[Dict]:
    """Scan DynamoDB table and return all items."""
    items = []
    response = table.scan()
    items.extend(response.get('Items', []))
    while 'LastEvaluatedKey' in response:
        response = table.scan(ExclusiveStartKey=response['LastEvaluatedKey'])
        items.extend(response.get('Items', []))
    return items

def fetch_user_ratings(user_id: str) -> List[Dict]:
    """Query or scan for ratings by a user."""
    response = table.scan(
        FilterExpression="user_id = :uid",
        ExpressionAttributeValues={':uid': user_id}
    )
    return response.get('Items', [])