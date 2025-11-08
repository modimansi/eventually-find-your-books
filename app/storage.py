import os
import boto3
from typing import List, Dict
from app.config import settings

# Use boto3 client/resource (sync). We can call it from async endpoints via threadpool.
session = boto3.Session(region_name=settings.aws_region)
dynamodb = session.resource('dynamodb')
table = dynamodb.Table(settings.dynamodb_table)

def fetch_all_ratings() -> List[Dict]:
    """Scan DynamoDB table and return all items (simple for demo)."""
    items = []
    response = table.scan()
    items.extend(response.get('Items', []))
    while 'LastEvaluatedKey' in response:
        response = table.scan(ExclusiveStartKey=response['LastEvaluatedKey'])
        items.extend(response.get('Items', []))
    return items

def fetch_user_ratings(user_id: str) -> List[Dict]:
    """Query or scan for ratings by a user. Adjust if you have a GSI."""
    # Simple scan filter for demo; for prod use GSI keyed on user_id.
    response = table.scan(
        FilterExpression="user_id = :uid",
        ExpressionAttributeValues={':uid': user_id}
    )
    return response.get('Items', [])
