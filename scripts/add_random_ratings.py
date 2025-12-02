#!/usr/bin/env python3
"""
Add random ratings to the DynamoDB ratings table.

- Generates ~ num_users * ratings_per_user ratings across different users
- Uses existing books from the books table

Example:
  python scripts/add_random_ratings.py \
    --region us-west-2 \
    --books-table book-recommendation-books-dev \
    --ratings-table book-recommendation-ratings-dev \
    --num-users 500 \
    --ratings-per-user 10
"""

from __future__ import annotations

import argparse
import os
import random
import string
from typing import List, Set

import boto3
from botocore.config import Config as BotoConfig


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Generate and insert random ratings into DynamoDB.")
    parser.add_argument("--region", default=os.getenv("AWS_REGION", "us-west-2"), help="AWS region")
    parser.add_argument("--books-table", required=True, help="DynamoDB books table name")
    parser.add_argument("--ratings-table", required=True, help="DynamoDB ratings table name")

    parser.add_argument("--num-users", type=int, default=500, help="Number of distinct users")
    parser.add_argument("--ratings-per-user", type=int, default=10, help="Ratings per user")
    parser.add_argument("--max-books-scan", type=int, default=20000, help="Max books to scan from books table")
    parser.add_argument("--user-prefix", default="user", help="User ID prefix (e.g., 'user')")
    parser.add_argument("--seed", type=int, default=None, help="Random seed for reproducibility")
    return parser.parse_args()


def scan_book_ids(dynamodb, books_table_name: str, max_items: int) -> List[str]:
    books_table = dynamodb.Table(books_table_name)
    book_ids: List[str] = []
    kwargs = {
        "ProjectionExpression": "book_id",
    }

    while True:
        resp = books_table.scan(**kwargs)
        for item in resp.get("Items", []):
            book_id = item.get("book_id")
            if book_id:
                book_ids.append(book_id)
                if len(book_ids) >= max_items:
                    return book_ids
        if "LastEvaluatedKey" not in resp:
            break
        kwargs["ExclusiveStartKey"] = resp["LastEvaluatedKey"]
    return book_ids


def generate_user_ids(prefix: str, num_users: int) -> List[str]:
    # Simple deterministic user IDs: user1..userN
    return [f"{prefix}{i}" for i in range(1, num_users + 1)]


def sample_ratings_for_user(user_id: str, candidate_book_ids: List[str], ratings_per_user: int) -> List[dict]:
    # Ensure unique books per user
    if ratings_per_user > len(candidate_book_ids):
        raise ValueError("ratings_per_user cannot exceed number of available candidate books")
    selected = random.sample(candidate_book_ids, ratings_per_user)

    # Slightly bias ratings toward 3-5 stars
    choices = [1, 2, 3, 4, 5]
    weights = [0.10, 0.15, 0.30, 0.25, 0.20]
    result = []
    for book_id in selected:
        rating = random.choices(choices, weights=weights, k=1)[0]
        result.append({
            "user_id": user_id,
            "book_id": book_id,
            "rating": int(rating),
        })
    return result


def put_ratings_batch(dynamodb, ratings_table_name: str, ratings: List[dict]) -> None:
    ratings_table = dynamodb.Table(ratings_table_name)
    with ratings_table.batch_writer(overwrite_by_pkeys=["user_id", "book_id"]) as batch:
        for item in ratings:
            batch.put_item(Item=item)


def main() -> None:
    args = parse_args()
    if args.seed is not None:
        random.seed(args.seed)

    boto_cfg = BotoConfig(retries={"max_attempts": 10, "mode": "standard"})
    dynamodb = boto3.resource("dynamodb", region_name=args.region, config=boto_cfg)

    print(f"Scanning books from '{args.books_table}' (max {args.max_books_scan}) ...")
    book_ids = scan_book_ids(dynamodb, args.books_table, args.max_books_scan)
    if not book_ids:
        raise RuntimeError("No book_ids found in books table. Ensure data is loaded.")
    print(f"Found {len(book_ids)} book_ids.")

    user_ids = generate_user_ids(args.user_prefix, args.num_users)
    total_to_write = args.num_users * args.ratings_per_user
    print(f"Generating ~{total_to_write} ratings for {args.num_users} users ...")

    # For variance across users, use a random subset of books per user without duplication per user
    # but allow the same book to be rated by many users.
    written = 0
    batch: List[dict] = []
    for user_id in user_ids:
        ratings = sample_ratings_for_user(user_id, book_ids, args.ratings_per_user)
        batch.extend(ratings)
        # Flush in chunks to avoid large memory
        if len(batch) >= 1000:
            put_ratings_batch(dynamodb, args.ratings_table, batch)
            written += len(batch)
            print(f"Wrote {written}/{total_to_write} ratings...")
            batch = []

    if batch:
        put_ratings_batch(dynamodb, args.ratings_table, batch)
        written += len(batch)

    print(f"Done. Wrote {written} ratings into '{args.ratings_table}'.")


if __name__ == "__main__":
    main()


