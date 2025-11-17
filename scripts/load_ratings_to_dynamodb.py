"""
Load Open Library Ratings Dump into DynamoDB (Ratings Table)

Usage:
    python3 scripts/load_ratings_to_dynamodb.py \
        --file data-processing/ol_ratings_dump.txt \
        --table Ratings \
        --region us-west-2 \
        --limit 50000

Arguments:
    --file   Path to the rating dump (TSV from Open Library)
    --table  DynamoDB table name (Ratings)
    --region AWS region (default: us-west-2)
    --limit  Maximum number of ratings to import (default: 50,000)
"""

import argparse
import boto3
from datetime import datetime, UTC
from decimal import Decimal
from typing import Optional, Tuple


def parse_line(line: str) -> Optional[Tuple[str, Decimal]]:
    """
    Parse a single line from the Open Library rating dump.

    Expected format (tab separated):
        /works/OL1629179W    /books/OL22981670M    5    2018-06-20

    Returns:
        (book_id, rating) where:
            book_id = "OL1629179W"
            rating  = Decimal("5")

        or None if the line is invalid.
    """
    parts = line.strip().split("\t")
    if len(parts) < 3:
        return None

    work_key = parts[0].strip()
    rating_str = parts[2].strip()

    if not work_key.startswith("/works/"):
        return None

    # Convert rating string → Decimal (DynamoDB requires Decimal, not float)
    try:
        rating_val = Decimal(rating_str)
    except Exception:
        return None

    # Basic validation
    if rating_val < Decimal("0.5") or rating_val > Decimal("5.0"):
        return None

    # "/works/OL1234W" → "OL1234W"
    book_id = work_key.split("/")[-1]
    return book_id, rating_val


def batch_write(dynamodb, table_name: str, items):
    """
    Write a batch of items into DynamoDB using batch_writer().
    """
    table = dynamodb.Table(table_name)
    with table.batch_writer() as batch:
        for item in items:
            batch.put_item(Item=item)


def load_ratings(file_path: str, table_name: str, region: str, limit: int):
    """
    Load rating records into DynamoDB.

    Arguments:
        file_path   Path to the Open Library TSV rating dump
        table_name  DynamoDB table name
        region      AWS region
        limit       Max number of ratings to write (limit <= 0 means unlimited)
    """
    dynamodb = boto3.resource("dynamodb", region_name=region)

    batch_items = []
    written_count = 0

    print("\n===================================================")
    print("LOADING RATINGS INTO DYNAMODB")
    print("===================================================")
    print(f"Source file   : {file_path}")
    print(f"DynamoDB Table: {table_name}")
    print(f"Region        : {region}")
    print(f"Max items     : {limit if limit > 0 else 'no limit'}")
    print("===================================================\n")

    with open(file_path, "r", encoding="utf-8", errors="ignore") as f:
        for line_num, line in enumerate(f, 1):

            # Stop if limit reached
            if limit > 0 and written_count >= limit:
                break

            parsed = parse_line(line)
            if not parsed:
                continue

            book_id, rating = parsed

            # Generate a fake user_id (Open Library does not expose real user IDs)
            user_id = f"user_{written_count}"

            item = {
                "user_id": user_id,
                "book_id": book_id,
                "rating": rating,  # Must be Decimal
                "created_at": datetime.now(UTC).isoformat(),
            }

            batch_items.append(item)
            written_count += 1

            # DynamoDB batch write limit = 25
            if len(batch_items) == 25:
                batch_write(dynamodb, table_name, batch_items)
                batch_items = []

            # Logging progress
            if line_num % 50_000 == 0:
                print(f"Scanned {line_num:,} lines... (written {written_count:,})")

    # Write remaining items
    if batch_items:
        batch_write(dynamodb, table_name, batch_items)

    print("\n===================================================")
    print("DONE.")
    print(f"Total ratings written: {written_count:,}")
    print("===================================================\n")


def main():
    parser = argparse.ArgumentParser(
        description="Load Open Library ratings dump into a DynamoDB Ratings table."
    )
    parser.add_argument("--file", required=True,
                        help="Path to rating dump file (TSV)")
    parser.add_argument("--table", required=True,
                        help="DynamoDB table name (Ratings)")
    parser.add_argument("--region", default="us-west-2",
                        help="AWS region (default: us-west-2)")
    parser.add_argument("--limit", type=int, default=50000,
                        help="Max number of ratings to import (default: 50000)")

    args = parser.parse_args()
    load_ratings(args.file, args.table, args.region, args.limit)


if __name__ == "__main__":
    main()