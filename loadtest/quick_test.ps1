# Quick Load Test Script for Windows PowerShell
# Tests all APIs with sample data

$ALB = "http://book-alb-dev-552414421.us-west-2.elb.amazonaws.com"
$BOOK_IDS = @("OL15936512W", "OL7353617M", "OL8193426M", "OL2055405M")

Write-Host "=== Testing Book Recommendation APIs ===" -ForegroundColor Cyan
Write-Host "ALB: $ALB`n" -ForegroundColor Yellow

# Test 1: Search API
Write-Host "[1/8] Testing Search API..." -ForegroundColor Green
$searchBody = @{query="Harry Potter"; limit=5} | ConvertTo-Json
$response = Invoke-RestMethod -Uri "$ALB/search" -Method POST -Body $searchBody -ContentType "application/json" -ErrorAction SilentlyContinue
if ($response) {
    Write-Host "✅ Search API: OK - Found $($response.results.Count) books" -ForegroundColor Green
} else {
    Write-Host "❌ Search API: FAILED" -ForegroundColor Red
}

# Test 2: Advanced Search
Write-Host "[2/8] Testing Advanced Search..." -ForegroundColor Green
$advSearchBody = @{title="Harry"; min_year=1990; max_year=2010; limit=10} | ConvertTo-Json
$response = Invoke-RestMethod -Uri "$ALB/search/advanced" -Method POST -Body $advSearchBody -ContentType "application/json" -ErrorAction SilentlyContinue
if ($response) {
    Write-Host "✅ Advanced Search: OK - Found $($response.results.Count) books" -ForegroundColor Green
} else {
    Write-Host "❌ Advanced Search: FAILED" -ForegroundColor Red
}

# Test 3: Shard Search
Write-Host "[3/8] Testing Shard Search..." -ForegroundColor Green
$response = Invoke-RestMethod -Uri "$ALB/search/shard/HAR?limit=10" -Method GET -ErrorAction SilentlyContinue
if ($response) {
    Write-Host "✅ Shard Search: OK - Found $($response.results.Count) books" -ForegroundColor Green
} else {
    Write-Host "❌ Shard Search: FAILED" -ForegroundColor Red
}

# Test 4: Book Detail API (Single)
Write-Host "[4/8] Testing Book Detail API (Single)..." -ForegroundColor Green
$bookId = $BOOK_IDS[0]
$response = Invoke-RestMethod -Uri "$ALB/books/$bookId" -Method GET -ErrorAction SilentlyContinue
if ($response) {
    Write-Host "✅ Book Detail (Single): OK - Got book: $($response.title)" -ForegroundColor Green
} else {
    Write-Host "❌ Book Detail (Single): FAILED" -ForegroundColor Red
}

# Test 5: Book Detail API (Batch)
Write-Host "[5/8] Testing Book Detail API (Batch)..." -ForegroundColor Green
$batchBody = @{book_ids=$BOOK_IDS} | ConvertTo-Json
$response = Invoke-RestMethod -Uri "$ALB/books/batch" -Method POST -Body $batchBody -ContentType "application/json" -ErrorAction SilentlyContinue
if ($response) {
    Write-Host "✅ Book Detail (Batch): OK - Got $($response.books.Count) books" -ForegroundColor Green
} else {
    Write-Host "❌ Book Detail (Batch): FAILED" -ForegroundColor Red
}

# Test 6: Ratings API (Rate Book)
Write-Host "[6/8] Testing Ratings API (Rate Book)..." -ForegroundColor Green
$rateBody = @{user_id="testuser123"; rating=5} | ConvertTo-Json
$response = Invoke-RestMethod -Uri "$ALB/books/$bookId/rate" -Method POST -Body $rateBody -ContentType "application/json" -ErrorAction SilentlyContinue
if ($response) {
    Write-Host "✅ Rate Book: OK - $($response.message)" -ForegroundColor Green
} else {
    Write-Host "❌ Rate Book: FAILED" -ForegroundColor Red
}

# Test 7: Ratings API (Get Book Ratings)
Write-Host "[7/8] Testing Ratings API (Get Book Ratings)..." -ForegroundColor Green
$response = Invoke-RestMethod -Uri "$ALB/books/$bookId/ratings" -Method GET -ErrorAction SilentlyContinue
if ($response) {
    Write-Host "✅ Get Book Ratings: OK - Average: $($response.average_rating)" -ForegroundColor Green
} else {
    Write-Host "❌ Get Book Ratings: FAILED" -ForegroundColor Red
}

# Test 8: Ratings API (Get User Ratings)
Write-Host "[8/8] Testing Ratings API (Get User Ratings)..." -ForegroundColor Green
$response = Invoke-RestMethod -Uri "$ALB/users/testuser123/ratings" -Method GET -ErrorAction SilentlyContinue
if ($response) {
    Write-Host "✅ Get User Ratings: OK - User has $($response.ratings.Count) ratings" -ForegroundColor Green
} else {
    Write-Host "❌ Get User Ratings: FAILED" -ForegroundColor Red
}

Write-Host "`n=== All Tests Complete ===" -ForegroundColor Cyan

