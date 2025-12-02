"""
Batch load books JSONL into DynamoDB Books table.

Usage example:

  python3 load_books_to_dynamodb.py \
    --file ../Data_process/books_english_top50k_with_ratings.jsonl \
    --table Books \
    --region us-west-2

Make sure your AWS credentials & region are configured (env vars or ~/.aws).
"""

import argparse
import json
from decimal import Decimal
from typing import Iterator, Optional

import boto3
from botocore.exceptions import ClientError
import hashlib  # used for stable hashing when computing shard_key


def iter_jsonl(path: str) -> Iterator[dict]:
    """
    Stream JSON objects from a JSONL file, one line at a time.
    Use parse_float=Decimal so DynamoDB accepts numeric types.
    """
    with open(path, "r", encoding="utf-8") as f:
        for line_num, line in enumerate(f, 1):
            line = line.strip()
            if not line:
                continue
            try:
                obj = json.loads(line, parse_float=Decimal)
                yield obj
            except json.JSONDecodeError as e:
                print(f"[WARN] Line {line_num}: JSON decode error: {e}")
                continue


# UPDATED: helper to compute composite shard_key for each book
def compute_shard_key(book: dict) -> str:
    """
    Compute composite shard_key based on the first letter of the title
    and a stable hash for hot shards (A, S, T) to split them into 2.

    Final composite sharding strategy (16 shards total):

      Hot letters (split into 2 shards each, via hashing):
        - A  -> A1, A2
        - S  -> S1, S2
        - T  -> T1, T2

      Other letters grouped into 10 shards:

        - C          -> "C"
        - L          -> "L"
        - M          -> "M"
        - P          -> "P"

        - B, E       -> "BE"
        - D, J, K    -> "DJK"
        - F, G, Q, X -> "FGQX"
        - H, I, Y    -> "HIY"
        - N, O, U, V, Z -> "NOUVZ"
        - R, W       -> "RW"

      Fallback / others (non A–Z) -> "0"
    """
    title_lower = book.get("title_lower") or book.get("title", "")
    title_lower = title_lower.strip().lower()

    if not title_lower:
        first = "0"
    else:
        first = title_lower[0].upper()
        if not ("A" <= first <= "Z"):
            first = "0"

    # Hot letters: A, S, T -> split each into 2 shards with stable hash
    if first in ("A", "S", "T"):
        raw = f"{book.get('book_id', '')}:{title_lower}"
        h = hashlib.md5(raw.encode("utf-8")).hexdigest()
        suffix = "1" if int(h[-1], 16) % 2 == 0 else "2"
        return f"{first}{suffix}"

    # Grouping for the remaining letters
    group_map = {
        # single-letter shards
        "C": "C",
        "L": "L",
        "M": "M",
        "P": "P",

        # multi-letter shards
        "B": "BE",
        "E": "BE",

        "D": "DJK",
        "J": "DJK",
        "K": "DJK",

        "F": "FGQX",
        "G": "FGQX",
        "Q": "FGQX",
        "X": "FGQX",

        "H": "HIY",
        "I": "HIY",
        "Y": "HIY",

        "N": "NOUVZ",
        "O": "NOUVZ",
        "U": "NOUVZ",
        "V": "NOUVZ",
        "Z": "NOUVZ",

        "R": "RW",
        "W": "RW",
    }

    if first in group_map:
        return group_map[first]

    # Fallback bucket for non A–Z or anything unexpected
    return "0"


def load_books(file_path: str, table_name: str, region: Optional[str] = None):
    """
    Load books from JSONL file into DynamoDB using BatchWrite (25 items per request).
    """
    print("=" * 70)
    print("LOADING BOOKS INTO DYNAMODB")
    print("=" * 70)
    print(f"Source file : {file_path}")
    print(f"DynamoDB    : {table_name}")
    if region:
        print(f"Region      : {region}")
    print()

    # Create DynamoDB resource
    if region:
        dynamodb = boto3.resource("dynamodb", region_name=region)
    else:
        dynamodb = boto3.resource("dynamodb")

    table = dynamodb.Table(table_name)

    total = 0
    with table.batch_writer(overwrite_by_pkeys=["book_id"]) as batch:
        for book in iter_jsonl(file_path):
            # Basic sanity check
            book_id = book.get("book_id")
            if not book_id:
                # fallback for legacy "key"
                book_id = book.get("key")
                if not book_id:
                    print("[WARN] Skip item without book_id/key")
                    continue
                book["book_id"] = book_id

            # Default rating fields
            book.setdefault("rating_count", 0)
            book.setdefault("avg_rating", Decimal("0"))

            # Compute composite shard key if not already present
            if not book.get("shard_key"):
                book["shard_key"] = compute_shard_key(book)

            try:
                batch.put_item(Item=book)
                total += 1
            except ClientError as e:
                print(f"[ERROR] Failed to write book_id={book_id}: {e}")
                continue

            if total % 1000 == 0:
                print(f"  Written {total:,} items ...")

    print()
    print(f"COMPLETE: {total:,} items written to DynamoDB table '{table_name}'")
    print("=" * 70)


def main():
    parser = argparse.ArgumentParser(
        description="Batch load books JSONL into DynamoDB Books table"
    )
    parser.add_argument(
        "--file",
        required=True,
        help="Input JSONL file, e.g. books_english_top50k_with_ratings.jsonl",
    )
    parser.add_argument(
        "--table",
        required=True,
        help="DynamoDB table name, e.g. Books",
    )
    parser.add_argument(
        "--region",
        required=False,
        help="AWS region, e.g. us-west-2 (optional if already configured)",
    )

    args = parser.parse_args()
    load_books(args.file, args.table, args.region)


if __name__ == "__main__":
    main()