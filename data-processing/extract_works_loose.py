"""
Extract English books from Open Library works dump (loose version).

This "loose" extractor keeps more records by relaxing strict filters:
  - description is optional
  - author_name may fall back to author_id (no hard filter)
  - subjects required (to keep some semantic context)

Target JSON schema per line (JSONL):

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
  "subjects": ["Fiction", "Romance", "Historical Fiction"],
  "language": "en",
  "description": "She spied him in the shadows ...",
  "cover_id": 8632093,
  "avg_rating": 0.0,
  "rating_count": 0
}

Usage:
    python3 extract_works_loose.py \
        --input ol_dump_works_2025-09-30.txt.gz \
        --authors ol_dump_authors_2025-09-30.txt.gz \
        --output books_english_loose_150k.jsonl \
        --limit 150000
"""

import argparse
import gzip
import json
import re
from typing import Iterable, Optional, Dict, Any, List
from collections import Counter


def open_maybe_gzip(path: str) -> Iterable[str]:
    """Open file with or without gzip based on extension."""
    if path.endswith(".gz"):
        f = gzip.open(path, "rt", encoding="utf-8", errors="ignore")
    else:
        f = open(path, "r", encoding="utf-8", errors="ignore")
    try:
        for line in f:
            yield line
    finally:
        f.close()


def extract_title_prefix(title: str) -> str:
    """Extract title prefix for A-Z sharding."""
    if not title:
        return "0"
    for ch in title.strip():
        if ch.isalpha() and 'A' <= ch.upper() <= 'Z':
            return ch.upper()
    return "0"


def extract_year(first_publish_date) -> Optional[int]:
    """Extract year from date string."""
    if not isinstance(first_publish_date, str):
        return None
    m = re.search(r"\d{4}", first_publish_date)
    if not m:
        return None
    try:
        year = int(m.group(0))
        if 1000 <= year <= 2025:
            return year
    except ValueError:
        pass
    return None


def load_author_map(authors_dump_path: str, max_authors: int = 2_000_000) -> Dict[str, str]:
    """Load author mapping: /authors/OLxxxA -> Name"""
    author_map: Dict[str, str] = {}
    count = 0
    print("=" * 70)
    print(f"Loading authors from {authors_dump_path} ...")
    for line_num, line in enumerate(open_maybe_gzip(authors_dump_path), start=1):
        line = line.strip()
        if not line:
            continue
        parts = line.split("\t")
        if len(parts) < 2:
            continue
        json_str = parts[-1]
        try:
            author = json.loads(json_str)
        except json.JSONDecodeError:
            continue

        key = author.get("key")
        name = author.get("name")
        if not key or not name:
            continue

        author_map[key] = name
        if key.startswith("/authors/"):
            short_id = key.split("/")[-1]
            author_map[short_id] = name

        count += 1
        if count % 100_000 == 0:
            print(f"  Loaded {count:,} authors...")
        if count >= max_authors:
            print(f"  Limit reached ({max_authors:,})")
            break

    print(f"✅ Author map ready with {len(author_map):,} entries.\n")
    return author_map


def extract_authors(work_json: dict, author_map: Dict[str, str]) -> List[dict]:
    """Extract authors with fallback to author_id if no name found."""
    authors: List[dict] = []
    raw_authors = work_json.get("authors") or []
    for a in raw_authors:
        author_key: Optional[str] = None
        if isinstance(a, str):
            author_key = a
        elif isinstance(a, dict):
            if "key" in a:
                author_key = a["key"]
            elif "author" in a and isinstance(a["author"], dict):
                author_key = a["author"].get("key")
        if not author_key:
            continue
        if author_key.startswith("/authors/"):
            author_id = author_key.split("/")[-1]
            full_key = author_key
        else:
            author_id = author_key
            full_key = f"/authors/{author_key}"

        author_name = author_map.get(full_key) or author_map.get(author_id) or author_id
        authors.append({"author_id": author_id, "author_name": author_name})
    return authors


def extract_language(work_json: dict) -> str:
    """Extract language code (default 'unknown')."""
    langs = work_json.get("languages") or []
    if not langs:
        return "unknown"
    first = langs[0] if isinstance(langs, list) else {}
    if not isinstance(first, dict):
        return "unknown"
    key = first.get("key", "")
    code = key.split("/")[-1] if key else ""
    if code in ["eng", "en"]:
        return "en"
    return code or "unknown"


def is_english_book(work_json: dict) -> bool:
    """Heuristic check for English books."""
    lang = extract_language(work_json)
    if lang == "en":
        return True
    title = work_json.get("title", "")
    if title and 'A' <= title[0].upper() <= 'Z' and lang == "unknown":
        return True
    return False


def get_popularity_score(work_json: dict) -> int:
    """Simple popularity score combining edition_count, ratings_count, subjects, and cover."""
    score = 0
    if isinstance(work_json.get("edition_count"), int):
        score += work_json["edition_count"] * 10
    if isinstance(work_json.get("ratings_count"), int):
        score += work_json["ratings_count"] * 5
    score += len(work_json.get("subjects") or [])
    if work_json.get("covers"):
        score += 20
    return score


def extract_description(work_json: dict) -> Optional[str]:
    """Extract description if available (string or dict)."""
    desc = work_json.get("description")
    if isinstance(desc, dict):
        return desc.get("value")
    if isinstance(desc, str):
        return desc
    return None


def extract_cover_id(work_json: dict) -> Optional[int]:
    """Extract first cover id from covers[]."""
    covers = work_json.get("covers") or []
    if isinstance(covers, list) and covers:
        first = covers[0]
        if isinstance(first, int):
            return first
    return None


def process_works_dump(input_path: str, authors_path: str, output_path: str, limit: int = 50000):
    """Main extraction function."""
    print("=" * 70)
    print("OPEN LIBRARY WORKS EXTRACTOR (LOOSE VERSION)")
    print("=" * 70)
    print(f"Input works:   {input_path}")
    print(f"Input authors: {authors_path}")
    print(f"Output:        {output_path}")
    print(f"Target:        {limit:,} English books (loose filters)")
    print()

    author_map = load_author_map(authors_path)
    candidates: List[Dict[str, Any]] = []

    print("Collecting English books...")
    for line_num, line in enumerate(open_maybe_gzip(input_path), start=1):
        line = line.strip()
        if not line:
            continue
        parts = line.split("\t")
        if len(parts) < 2:
            continue
        if "/type/work" not in parts[0]:
            continue

        try:
            work = json.loads(parts[-1])
        except json.JSONDecodeError:
            continue

        # English only
        if not is_english_book(work):
            continue

        title = work.get("title")
        if not title:
            continue

        key = work.get("key")
        if not key:
            continue

        authors = extract_authors(work, author_map)
        if not authors:
            continue

        title_prefix = extract_title_prefix(title)
        if title_prefix not in "ABCDEFGHIJKLMNOPQRSTUVWXYZ":
            continue

        popularity = get_popularity_score(work)
        candidates.append({
            "work": work,
            "key": key,
            "title": title,
            "authors": authors,
            "title_prefix": title_prefix,
            "popularity": popularity,
        })

        if len(candidates) % 20000 == 0:
            print(f"  Collected: {len(candidates):,} candidates...")

        if len(candidates) >= limit * 5:
            print(f"  Reached {len(candidates):,} candidates, stopping early.")
            break

    print(f"\nCollected {len(candidates):,} English works (loose filters).")
    print("Sorting by popularity...")
    candidates.sort(key=lambda x: x["popularity"], reverse=True)

    print(f"Writing top {limit:,} to {output_path}...")
    count_written = 0
    prefix_list = []

    with open(output_path, "w", encoding="utf-8") as out_f:
        for item in candidates:
            if count_written >= limit:
                break

            work = item["work"]
            raw_key = item["key"]
            book_id = raw_key.split("/")[-1] if isinstance(raw_key, str) else raw_key
            description = extract_description(work)  # optional
            cover_id = extract_cover_id(work)

            subjects = [
                s for s in (work.get("subjects") or [])
                if isinstance(s, str)
            ][:10]
            if not subjects:
                continue  # keep at least some context, but looser

            simplified: Dict[str, Any] = {
                "book_id": book_id,
                "title": item["title"],
                "title_prefix": item["title_prefix"],
                "title_lower": item["title"].lower(),
                "authors": item["authors"],
                "isbn_13": work.get("isbn_13") or [],
                "first_publish_year": extract_year(work.get("first_publish_date")),
                "subjects": subjects,
                "language": "en",
                "avg_rating": 0.0,
                "rating_count": 0,
            }

            if description:
                simplified["description"] = description
            if cover_id:
                simplified["cover_id"] = cover_id

            out_f.write(json.dumps(simplified, ensure_ascii=False) + "\n")
            count_written += 1
            prefix_list.append(item["title_prefix"])

            if count_written % 5000 == 0:
                print(f"  Written: {count_written:,} books")

    print(f"\n✅ DONE. Wrote {count_written:,} English books to {output_path}.\n")

    prefix_counter = Counter(prefix_list)
    print("Prefix distribution (sample):")
    for prefix, count in prefix_counter.most_common(10):
        pct = (count / len(prefix_list)) * 100
        bar = "█" * int(pct / 2)
        print(f"  {prefix}: {count:>6,} ({pct:>5.1f}%) {bar}")


def main():
    parser = argparse.ArgumentParser(description="Extract English books (loose filtering).")
    parser.add_argument("--input", required=True, help="Input works dump file (.txt.gz)")
    parser.add_argument("--authors", required=True, help="Authors dump file (.txt.gz)")
    parser.add_argument("--output", required=True, help="Output JSONL file")
    parser.add_argument("--limit", type=int, default=50000, help="Target number of books")
    args = parser.parse_args()
    process_works_dump(args.input, args.authors, args.output, args.limit)


if __name__ == "__main__":
    main()