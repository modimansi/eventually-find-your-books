#!/usr/bin/env python3
import argparse
import boto3
import time
from datetime import datetime

def parse_line(line):
    parts = line.strip().split("\t")
    if len(parts) < 3:
        return None

    work_key = parts[0].strip()     # /works/OLxxxxW
    rating_str = parts[2].strip()   # 1-5 rating

    if not work_key.startswith("/works/"):
        return None

    try:
        rating = float(rating_str)
    except:
        return None

    # convert "/works/OL1234W" -> "OL1234W"
    book_id = work_key.split("/")[-1]

    return book_id, rating


def batch_write(dynamodb, table_name, items):
    table = dynamodb.Table(table_name)
    with table.batch_writer() as batch:
        for item in items:
            batch.put_item(Item=item)


def load_ratings(file_path, table_name, region):
    dynamodb = boto3.resource("dynamodb", region_name=region)

    batch_items = []
    user_counter = 0

    print("\n===================================================")
    print("LOADING RATINGS INTO DYNAMODB")
    print("===================================================")
    print(f"Source file: {file_path}")
    print(f"DynamoDB Table: {table_name}")
    print("Region:", region)
    print()

    with open(file_path, "r", encoding="utf-8", errors="ignore") as f:
        for line_num, line in enumerate(f, 1):
            parsed = parse_line(line)
            if not parsed:
                continue

            book_id, rating = parsed

            # generate a fake user_id (Open Library doesn't include real users)
            user_id = f"user_{user_counter}"
            user_counter += 1

            item = {
                "user_id": user_id,
                "book_id": book_id,
                "rating": rating,
                "created_at": datetime.utcnow().isoformat() + "Z"
            }

            batch_items.append(item)

            if len(batch_items) == 25:  # batch limit for DynamoDB
                batch_write(dynamodb, table_name, batch_items)
                batch_items = []

            if line_num % 50000 == 0:
                print(f"Processed {line_num:,} lines...")

    # Flush remaining
    if batch_items:
        batch_write(dynamodb, table_name, batch_items)

    print("\n===================================================")
    print("DONE.")
    print(f"Total ratings written: {user_counter:,}")
    print("===================================================\n")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--file", required=True)
    parser.add_argument("--table", required=True)
    parser.add_argument("--region", default="us-west-2")
    args = parser.parse_args()

    load_ratings(args.file, args.table, args.region)


if __name__ == "__main__":
    main()