"""
Analyze book data and generate statistics.

Usage:
    python3 analyze_data.py books_english_50k.jsonl
"""

import json
import sys
from collections import Counter


def analyze_books(filename):
    """
    Analyze book data and generate statistics for:
      - language distribution
      - title_prefix distribution (A-Z sharding)
      - publication years
      - subjects
      - authors
      - ISBN coverage
      - rating coverage (avg_rating / rating_count)
      - a few sample books
    """
    print("=" * 70)
    print(f"DATA ANALYSIS: {filename}")
    print("=" * 70)

    # Read all books
    print("\nReading file...")
    books = []
    with open(filename, "r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if line:
                books.append(json.loads(line))

    total = len(books)
    print(f"Total books: {total:,}")

    if total == 0:
        print("No records found.")
        return True

    # Language distribution
    print("\n--- Language Distribution ---")
    languages = Counter(book.get("language", "unknown") for book in books)
    for lang, count in languages.most_common(10):
        percentage = (count / total) * 100
        print(f"  {lang:10s}: {count:>6,} ({percentage:>5.1f}%)")

    # Title prefix distribution
    print("\n--- Title Prefix Distribution (A-Z Sharding) ---")
    prefixes = Counter(book.get("title_prefix", "?") for book in books)
    for prefix in sorted(prefixes.keys()):
        count = prefixes[prefix]
        percentage = (count / total) * 100
        bar = "█" * int(percentage / 2)
        print(f"  {prefix}: {count:>6,} ({percentage:>5.1f}%) {bar}")

    # Year distribution
    print("\n--- Publication Year Statistics ---")
    years = [
        book.get("first_publish_year")
        for book in books
        if book.get("first_publish_year") is not None
    ]

    if years:
        print(f"  Books with year:  {len(years):,} ({len(years)/total*100:.1f}%)")
        print(f"  Earliest year:    {min(years)}")
        print(f"  Latest year:      {max(years)}")
        print(f"  Average year:     {sum(years)/len(years):.0f}")

        # Decade distribution
        decades = Counter((year // 10) * 10 for year in years)
        print("\n  Top decades:")
        for decade, count in decades.most_common(10):
            print(f"    {decade}s: {count:,}")
    else:
        print("  No year information available")

    # Subject distribution
    print("\n--- Top 25 Subjects ---")
    all_subjects = []
    for book in books:
        subjects = book.get("subjects", [])
        if subjects:
            all_subjects.extend(subjects)

    subject_counter = Counter(all_subjects)
    for subject, count in subject_counter.most_common(25):
        print(f"  {subject:40s}: {count:>5,}")

    # Author statistics
    print("\n--- Author Statistics ---")
    author_counts = [len(book.get("authors", [])) for book in books]
    if author_counts:
        avg_authors = sum(author_counts) / len(author_counts)
        single_author = sum(1 for c in author_counts if c == 1)
        multi_author = sum(1 for c in author_counts if c > 1)

        print(f"  Avg authors per book: {avg_authors:.2f}")
        print(f"  Max authors:          {max(author_counts)}")
        print(
            f"  Single author books:  {single_author:,} "
            f"({single_author/total*100:.1f}%)"
        )
        print(
            f"  Multi-author books:   {multi_author:,} "
            f"({multi_author/total*100:.1f}%)"
        )

    # ISBN coverage
    print("\n--- ISBN-13 Coverage ---")
    has_isbn = sum(1 for book in books if book.get("isbn_13"))
    no_isbn = total - has_isbn
    print(f"  With ISBN-13:    {has_isbn:,} ({has_isbn/total*100:.1f}%)")
    print(f"  Without ISBN-13: {no_isbn:,} ({no_isbn/total*100:.1f}%)")

    # Subject coverage
    print("\n--- Subject Coverage ---")
    has_subjects = sum(1 for book in books if book.get("subjects"))
    print(f"  With subjects:    {has_subjects:,} ({has_subjects/total*100:.1f}%)")
    print(
        f"  Without subjects: {total - has_subjects:,} "
        f"({(total-has_subjects)/total*100:.1f}%)"
    )

    # Rating coverage & distribution
    print("\n--- Rating Coverage & Distribution ---")
    rated_books = [b for b in books if b.get("rating_count", 0) > 0]
    num_rated = len(rated_books)
    print(f"  Books with ratings:    {num_rated:,} ({num_rated/total*100:.1f}%)")

    if num_rated > 0:
        avg_ratings = [b.get("avg_rating", 0.0) for b in rated_books]
        print(f"  Avg of avg_ratings:    {sum(avg_ratings)/len(avg_ratings):.3f}")
        print(f"  Min avg_rating:        {min(avg_ratings):.3f}")
        print(f"  Max avg_rating:        {max(avg_ratings):.3f}")

        # rating_count buckets: 1-5, 6-20, 21-100, 100+
        buckets = {
            "1-5": 0,
            "6-20": 0,
            "21-100": 0,
            "100+": 0,
        }
        for b in rated_books:
            rc = b.get("rating_count", 0)
            if rc <= 5:
                buckets["1-5"] += 1
            elif rc <= 20:
                buckets["6-20"] += 1
            elif rc <= 100:
                buckets["21-100"] += 1
            else:
                buckets["100+"] += 1

        print("\n  Rating count buckets:")
        for name, count in buckets.items():
            pct = (count / num_rated) * 100 if num_rated > 0 else 0
            print(f"    {name:6s}: {count:>6,} ({pct:>5.1f}%)")

        # Top 10 by rating_count
        print("\n  Top 10 by rating_count:")
        top_by_count = sorted(
            rated_books, key=lambda b: b.get("rating_count", 0), reverse=True
        )[:10]
        for b in top_by_count:
            print(
                f"    {b.get('rating_count', 0):>4} ratings | "
                f"{b.get('avg_rating', 0.0):>4.2f} ★ | "
                f"{b.get('title', '')[:60]}"
            )

        # Top 10 by avg_rating (with a minimum count)
        print("\n  Top 10 by avg_rating (rating_count >= 10):")
        filtered = [b for b in rated_books if b.get("rating_count", 0) >= 10]
        top_by_avg = sorted(
            filtered, key=lambda b: b.get("avg_rating", 0.0), reverse=True
        )[:10]
        for b in top_by_avg:
            print(
                f"    {b.get('avg_rating', 0.0):>4.2f} ★ | "
                f"{b.get('rating_count', 0):>4} ratings | "
                f"{b.get('title', '')[:60]}"
            )
    else:
        print("  No rating information available")

    # Sample books
    print("\n--- Sample Books (First 3) ---")
    for i, book in enumerate(books[:3], 1):
        print(f"\nBook {i}:")
        print(f"  ID:      {book.get('book_id')}")
        print(f"  Title:   {book.get('title')}")
        # authors use author_name in current schema
        author_names = ", ".join(
            a.get("author_name", "")
            for a in book.get("authors", [])
            if isinstance(a, dict)
        )
        print(f"  Authors: {author_names or 'N/A'}")
        print(f"  Year:    {book.get('first_publish_year', 'N/A')}")
        print(
            f"  Rating:  {book.get('avg_rating', 0.0)} "
            f"({book.get('rating_count', 0)} ratings)"
        )

    print("\n" + "=" * 70)
    return True


def main():
    if len(sys.argv) < 2:
        print("Usage: python analyze_data.py <file.jsonl>")
        print("Example: python analyze_data.py books_english_50k.jsonl")
        sys.exit(1)

    filename = sys.argv[1]

    try:
        analyze_books(filename)
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