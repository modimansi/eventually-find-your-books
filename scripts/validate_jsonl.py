"""
Validate JSONL book data file for required fields and data quality.

Usage:
    python3 validate_jsonl.py books_english_50k.jsonl
"""

import json
import sys
from collections import Counter


def validate_books(filename):
    """
    Validate JSONL file for book data.

    Current schema (per line):

        {
          "book_id": "OL1000046W",
          "title": "Confessions of a Little Black Gown",
          "title_prefix": "C",
          "title_lower": "confessions of a little black gown",
          "authors": [
            {
              "author_id": "OL92935A",
              "author_name": "Elizabeth Boyle"
            }
          ],
          "isbn_13": [],
          "first_publish_year": 2009,
          "subjects": [...],
          "language": "en",
          "description": "...",
          "cover_id": 8632093,
          "avg_rating": 4.3,
          "rating_count": 212
        }

    Required fields (for this validator):
      - book_id
      - title
      - title_prefix
      - title_lower
      - authors
      - language

    Optional fields:
      - isbn_13
      - first_publish_year
      - subjects
      - description
      - cover_id
      - avg_rating
      - rating_count
    """
    print("=" * 70)
    print(f"VALIDATING: {filename}")
    print("=" * 70)

    books = []
    parse_errors = 0

    # Step 1: Read JSONL file
    print("\n[1/5] Reading JSONL file...")
    with open(filename, "r", encoding="utf-8") as f:
        for line_num, line in enumerate(f, 1):
            line = line.strip()
            if not line:
                continue

            try:
                book = json.loads(line)
                books.append(book)
            except json.JSONDecodeError as e:
                print(f"ERROR: Line {line_num}: {e}")
                parse_errors += 1
                if parse_errors > 10:
                    print("ERROR: Too many parse errors. Stopping.")
                    return False

    total = len(books)
    print(f"SUCCESS: Loaded {total:,} books")

    if parse_errors > 0:
        print(f"WARNING: {parse_errors} lines had parse errors")

    # Step 2: Check required fields
    print("\n[2/5] Checking required fields...")

    # NOTE: key -> book_id; authors items now contain author_id/author_name
    required = ["book_id", "title", "title_prefix", "title_lower", "authors", "language"]

    missing_count = {field: 0 for field in required}
    sample_errors = []

    for i, book in enumerate(books):
        for field in required:
            if field not in book or book[field] in (None, "", []):
                missing_count[field] += 1
                if len(sample_errors) < 10:
                    sample_errors.append(
                        {
                            "line": i + 1,
                            "field": field,
                            "title": book.get("title", "Unknown"),
                        }
                    )

    total_missing = sum(missing_count.values())

    if total_missing == 0:
        print("SUCCESS: All required fields present")
    else:
        print(f"WARNING: {total_missing} missing required fields:")
        for field, count in missing_count.items():
            if count > 0:
                percentage = (count / total) * 100
                print(f"  - {field}: {count:,} ({percentage:.1f}%)")

        if sample_errors:
            print("\n  Sample errors:")
            for err in sample_errors:
                print(
                    f"    Line {err['line']}: missing '{err['field']}' in '{err['title']}'"
                )

    # Step 3: Check field types (sample)
    print("\n[3/5] Checking field types (sample)...")

    type_errors = 0
    sample_size = min(1000, total)

    for i, book in enumerate(books[:sample_size]):
        # authors: should be a list of objects with author_id / author_name
        if "authors" in book:
            if not isinstance(book["authors"], list):
                print(f"WARNING: Line {i+1}: 'authors' should be a list")
                type_errors += 1
            elif len(book["authors"]) > 0:
                first_author = book["authors"][0]
                if not isinstance(first_author, dict):
                    print(f"WARNING: Line {i+1}: 'authors' items should be objects")
                    type_errors += 1
                else:
                    # Check for author_id / author_name fields (soft check)
                    if "author_id" not in first_author:
                        print(
                            f"WARNING: Line {i+1}: author object missing 'author_id' field"
                        )
                        type_errors += 1
                    if "author_name" not in first_author:
                        print(
                            f"WARNING: Line {i+1}: author object missing 'author_name' field"
                        )
                        type_errors += 1

        # title_prefix should be a single character (A-Z or similar)
        if "title_prefix" in book:
            prefix = book["title_prefix"]
            if not isinstance(prefix, str) or len(prefix) != 1:
                print(
                    f"WARNING: Line {i+1}: 'title_prefix' should be single character, got '{prefix}'"
                )
                type_errors += 1

        # avg_rating / rating_count should be numeric if present
        if "avg_rating" in book and not isinstance(book["avg_rating"], (int, float)):
            print(f"WARNING: Line {i+1}: 'avg_rating' should be numeric")
            type_errors += 1
        if "rating_count" in book and not isinstance(book["rating_count"], int):
            print(f"WARNING: Line {i+1}: 'rating_count' should be int")
            type_errors += 1

    if type_errors == 0:
        print("SUCCESS: All field types look correct in sample")
    else:
        print(f"WARNING: {type_errors} type errors found in sample")

    # Step 4: Check optional fields coverage
    print("\n[4/5] Checking optional field coverage...")

    optional = [
        "isbn_13",
        "first_publish_year",
        "subjects",
        "description",
        "cover_id",
        "avg_rating",
        "rating_count",
    ]

    for field in optional:
        count = sum(1 for book in books if field in book and book[field])
        percentage = (count / total) * 100
        print(f"  - {field:16s}: {count:>6,} ({percentage:>5.1f}%)")

    # Step 5: Analyze title_prefix distribution
    print("\n[5/5] Analyzing title_prefix distribution...")

    prefix_counter = Counter(book.get("title_prefix", "?") for book in books)

    expected = set("ABCDEFGHIJKLMNOPQRSTUVWXYZ0")
    found = set(prefix_counter.keys())

    missing = expected - found
    unexpected = found - expected

    if missing:
        print(f"INFO: Missing prefixes: {', '.join(sorted(missing))}")

    if unexpected:
        print(
            f"WARNING: Unexpected prefixes (non-English / other chars): "
            f"{', '.join(sorted(unexpected))}"
        )

    az_count = sum(
        count for prefix, count in prefix_counter.items() if prefix in "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
    )
    az_percentage = (az_count / total) * 100

    print(f"\nBooks with A-Z prefix: {az_count:,} ({az_percentage:.1f}%)")

    print("\nTop 10 prefixes:")
    for prefix, count in prefix_counter.most_common(10):
        percentage = (count / total) * 100
        bar = "█" * int(percentage / 2)
        print(f"  {prefix}: {count:>6,} ({percentage:>5.1f}%) {bar}")

    # Summary
    print("\n" + "=" * 70)
    print("VALIDATION SUMMARY")
    print("=" * 70)
    print(f"Total books:          {total:,}")
    print(f"Parse errors:         {parse_errors}")
    print(f"Missing fields:       {total_missing}")
    print(f"Type errors (sample): {type_errors}")
    print(f"A-Z prefix books:     {az_count:,} ({az_percentage:.1f}%)")

    # Determine pass/fail (simple heuristic)
    critical_errors = parse_errors + (total_missing if total_missing > total * 0.05 else 0)

    if critical_errors == 0 and az_percentage >= 95:
        print("\nRESULT: PASSED - Ready for DynamoDB / search indexing")
        return True
    else:
        print(f"\nRESULT: FAILED - {critical_errors} estimated critical issues")
        if az_percentage < 95:
            print(f"         - Too many non-A-Z prefix books ({100 - az_percentage:.1f}%)")
        return False


def main():
    if len(sys.argv) > 1:
        filename = sys.argv[1]
    else:
        filename = "books_english_50k.jsonl"

    try:
        success = validate_books(filename)
        sys.exit(0 if success else 1)
    except FileNotFoundError:
        print(f"ERROR: File not found: {filename}")
        sys.exit(1)
    except Exception as e:
        print(f"ERROR: {e}")
        import traceback

        traceback.print_exc()
        sys.exit(1)


if __name__ == "__main__":
    main()