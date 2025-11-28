#!/bin/bash
# Quick Load Test Script for Linux/Mac
# Tests all APIs with sample data

ALB="http://book-alb-dev-552414421.us-west-2.elb.amazonaws.com"
BOOK_IDS=("OL15936512W" "OL7353617M" "OL8193426M" "OL2055405M")

echo "=== Testing Book Recommendation APIs ==="
echo "ALB: $ALB"
echo ""

# Test 1: Search API
echo "[1/8] Testing Search API..."
curl -s -X POST "$ALB/search" \
  -H "Content-Type: application/json" \
  -d '{"query":"Harry Potter","limit":5}' | jq -r '.results | length' > /dev/null 2>&1
if [ $? -eq 0 ]; then
    echo "✅ Search API: OK"
else
    echo "❌ Search API: FAILED"
fi

# Test 2: Advanced Search
echo "[2/8] Testing Advanced Search..."
curl -s -X POST "$ALB/search/advanced" \
  -H "Content-Type: application/json" \
  -d '{"title":"Harry","min_year":1990,"max_year":2010,"limit":10}' > /dev/null 2>&1
if [ $? -eq 0 ]; then
    echo "✅ Advanced Search: OK"
else
    echo "❌ Advanced Search: FAILED"
fi

# Test 3: Shard Search
echo "[3/8] Testing Shard Search..."
curl -s "$ALB/search/shard/HAR?limit=10" > /dev/null 2>&1
if [ $? -eq 0 ]; then
    echo "✅ Shard Search: OK"
else
    echo "❌ Shard Search: FAILED"
fi

# Test 4: Book Detail API (Single)
echo "[4/8] Testing Book Detail API (Single)..."
curl -s "$ALB/books/${BOOK_IDS[0]}" > /dev/null 2>&1
if [ $? -eq 0 ]; then
    echo "✅ Book Detail (Single): OK"
else
    echo "❌ Book Detail (Single): FAILED"
fi

# Test 5: Book Detail API (Batch)
echo "[5/8] Testing Book Detail API (Batch)..."
curl -s -X POST "$ALB/books/batch" \
  -H "Content-Type: application/json" \
  -d '{"book_ids":["OL15936512W","OL7353617M","OL8193426M"]}' > /dev/null 2>&1
if [ $? -eq 0 ]; then
    echo "✅ Book Detail (Batch): OK"
else
    echo "❌ Book Detail (Batch): FAILED"
fi

# Test 6: Ratings API (Rate Book)
echo "[6/8] Testing Ratings API (Rate Book)..."
curl -s -X POST "$ALB/books/${BOOK_IDS[0]}/rate" \
  -H "Content-Type: application/json" \
  -d '{"user_id":"testuser123","rating":5}' > /dev/null 2>&1
if [ $? -eq 0 ]; then
    echo "✅ Rate Book: OK"
else
    echo "❌ Rate Book: FAILED"
fi

# Test 7: Ratings API (Get Book Ratings)
echo "[7/8] Testing Ratings API (Get Book Ratings)..."
curl -s "$ALB/books/${BOOK_IDS[0]}/ratings" > /dev/null 2>&1
if [ $? -eq 0 ]; then
    echo "✅ Get Book Ratings: OK"
else
    echo "❌ Get Book Ratings: FAILED"
fi

# Test 8: Ratings API (Get User Ratings)
echo "[8/8] Testing Ratings API (Get User Ratings)..."
curl -s "$ALB/users/testuser123/ratings" > /dev/null 2>&1
if [ $? -eq 0 ]; then
    echo "✅ Get User Ratings: OK"
else
    echo "❌ Get User Ratings: FAILED"
fi

echo ""
echo "=== All Tests Complete ==="

