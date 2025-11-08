Recommendation Service
======================

Run locally:
1. Create .env with AWS_REGION and DYNAMODB_TABLE and REDIS_URL (default in docker-compose).
2. docker-compose up --build
3. Visit http://localhost:8000/docs for interactive API.

DynamoDB Local:
- The docker compose runs dynamodb-local on port 8001.
- You must create the ratings table (see README section below).

Creating DynamoDB table (local) example:
aws --endpoint-url http://localhost:8001 dynamodb create-table \
  --table-name book_ratings \
  --attribute-definitions AttributeName=work_id,AttributeType=S AttributeName=user_id,AttributeType=S \
  --key-schema AttributeName=work_id,KeyType=HASH AttributeName=user_id,KeyType=RANGE \
  --provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5
