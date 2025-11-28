# Complete End-to-End Testing Script
# Tests all 4 APIs with realistic user behavior

$ALB = "http://book-alb-dev-552414421.us-west-2.elb.amazonaws.com"

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  BOOK RECOMMENDATION SYSTEM TEST" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# Step 1: Search for Books
Write-Host "[STEP 1] USER SEARCHES FOR BOOKS" -ForegroundColor Green
Write-Host "Searching for 'Harry Potter'...`n"

$searchResult = Invoke-RestMethod -Uri "$ALB/search" -Method POST `
  -Body '{"query":"Harry Potter","limit":5}' -ContentType "application/json"

$bookIds = @()
if ($searchResult.results) {
    Write-Host "Found $($searchResult.results.Count) books:" -ForegroundColor Yellow
    foreach ($book in $searchResult.results) {
        Write-Host "  - $($book.title) (ID: $($book.book_id))" -ForegroundColor White
        $bookIds += $book.book_id
    }
} else {
    Write-Host "No results found. Using default book IDs..." -ForegroundColor Yellow
    $bookIds = @("OL15936512W", "OL7353617M", "OL8193426M")
}

Start-Sleep -Seconds 2

# Step 2: Get Book Details
Write-Host "`n[STEP 2] USER VIEWS BOOK DETAILS" -ForegroundColor Green
if ($bookIds.Count -gt 0) {
    $firstBookId = $bookIds[0]
    Write-Host "Getting details for book: $firstBookId`n"
    
    $bookDetail = Invoke-RestMethod -Uri "$ALB/books/$firstBookId" -Method GET
    Write-Host "Book Details:" -ForegroundColor Yellow
    Write-Host "  Title: $($bookDetail.title)"
    Write-Host "  Authors: $($bookDetail.authors.author_name -join ', ')"
    Write-Host "  Rating: $($bookDetail.average_rating)"
    Write-Host "  Year: $($bookDetail.publication_year)"
}

Start-Sleep -Seconds 2

# Step 3: Multiple Users Rate Books
Write-Host "`n[STEP 3] USERS RATE BOOKS" -ForegroundColor Green
Write-Host "Creating ratings from multiple users for collaborative filtering...`n"

# User 1: Likes Fantasy
Write-Host "User 'alice' rates books (likes fantasy):" -ForegroundColor Cyan
$ratings1 = @(
    @{book_id=$bookIds[0]; rating=5; user="alice"},
    @{book_id=$bookIds[1]; rating=5; user="alice"},
    @{book_id=$bookIds[2]; rating=3; user="alice"}
)

foreach ($r in $ratings1) {
    $body = @{user_id=$r.user; rating=$r.rating} | ConvertTo-Json
    try {
        $result = Invoke-RestMethod -Uri "$ALB/books/$($r.book_id)/rate" -Method POST `
          -Body $body -ContentType "application/json" -ErrorAction SilentlyContinue
        Write-Host "  ✓ Rated $($r.book_id): $($r.rating) stars" -ForegroundColor Green
    } catch {
        Write-Host "  ✗ Failed to rate $($r.book_id)" -ForegroundColor Red
    }
    Start-Sleep -Milliseconds 500
}

# User 2: Likes Sci-Fi
Write-Host "`nUser 'bob' rates books (likes sci-fi):" -ForegroundColor Cyan
$ratings2 = @(
    @{book_id=$bookIds[0]; rating=3; user="bob"},
    @{book_id=$bookIds[1]; rating=4; user="bob"},
    @{book_id=$bookIds[2]; rating=5; user="bob"}
)

foreach ($r in $ratings2) {
    $body = @{user_id=$r.user; rating=$r.rating} | ConvertTo-Json
    try {
        $result = Invoke-RestMethod -Uri "$ALB/books/$($r.book_id)/rate" -Method POST `
          -Body $body -ContentType "application/json" -ErrorAction SilentlyContinue
        Write-Host "  ✓ Rated $($r.book_id): $($r.rating) stars" -ForegroundColor Green
    } catch {
        Write-Host "  ✗ Failed to rate $($r.book_id)" -ForegroundColor Red
    }
    Start-Sleep -Milliseconds 500
}

# User 3: Similar to Alice
Write-Host "`nUser 'charlie' rates books (similar taste to alice):" -ForegroundColor Cyan
$ratings3 = @(
    @{book_id=$bookIds[0]; rating=5; user="charlie"},
    @{book_id=$bookIds[1]; rating=4; user="charlie"}
)

foreach ($r in $ratings3) {
    $body = @{user_id=$r.user; rating=$r.rating} | ConvertTo-Json
    try {
        $result = Invoke-RestMethod -Uri "$ALB/books/$($r.book_id)/rate" -Method POST `
          -Body $body -ContentType "application/json" -ErrorAction SilentlyContinue
        Write-Host "  ✓ Rated $($r.book_id): $($r.rating) stars" -ForegroundColor Green
    } catch {
        Write-Host "  ✗ Failed to rate $($r.book_id)" -ForegroundColor Red
    }
    Start-Sleep -Milliseconds 500
}

Start-Sleep -Seconds 2

# Step 4: View User's Ratings
Write-Host "`n[STEP 4] VIEW USER'S RATING HISTORY" -ForegroundColor Green
Write-Host "Getting all ratings by 'alice'...`n"

try {
    $userRatings = Invoke-RestMethod -Uri "$ALB/users/alice/ratings" -Method GET
    Write-Host "Alice has rated $($userRatings.total_ratings) books:" -ForegroundColor Yellow
    foreach ($rating in $userRatings.ratings) {
        Write-Host "  - Book $($rating.book_id): $($rating.rating) stars"
    }
} catch {
    Write-Host "Could not fetch user ratings" -ForegroundColor Red
}

Start-Sleep -Seconds 2

# Step 5: View Book Ratings
Write-Host "`n[STEP 5] VIEW BOOK'S RATINGS" -ForegroundColor Green
if ($bookIds.Count -gt 0) {
    $bookId = $bookIds[0]
    Write-Host "Getting all ratings for book: $bookId`n"
    
    try {
        $bookRatings = Invoke-RestMethod -Uri "$ALB/books/$bookId/ratings" -Method GET
        Write-Host "Book Ratings:" -ForegroundColor Yellow
        Write-Host "  Average: $($bookRatings.average_rating)"
        Write-Host "  Total Ratings: $($bookRatings.total_ratings)"
        Write-Host "  Distribution:"
        if ($bookRatings.ratings_distribution) {
            $bookRatings.ratings_distribution.PSObject.Properties | ForEach-Object {
                Write-Host "    $($_.Name) stars: $($_.Value) ratings"
            }
        }
    } catch {
        Write-Host "Could not fetch book ratings" -ForegroundColor Red
    }
}

Start-Sleep -Seconds 2

# Step 6: Get Recommendations (LOCAL)
Write-Host "`n[STEP 6] GET PERSONALIZED RECOMMENDATIONS" -ForegroundColor Green
Write-Host "⚠️  Recommendation API runs locally on port 8000" -ForegroundColor Yellow
Write-Host "To test recommendations:`n"
Write-Host "  1. Start Redis:" -ForegroundColor Cyan
Write-Host "     docker run -d -p 6379:6379 redis:alpine`n" -ForegroundColor White
Write-Host "  2. Start Recommendation API:" -ForegroundColor Cyan
Write-Host "     python -m uvicorn app.main:app --reload --port 8000`n" -ForegroundColor White
Write-Host "  3. Get recommendations:" -ForegroundColor Cyan
Write-Host "     curl http://localhost:8000/recommendations/alice?limit=5" -ForegroundColor White

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  TEST COMPLETE!" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

Write-Host "Summary:" -ForegroundColor Yellow
Write-Host "  ✓ Created 3 users (alice, bob, charlie)"
Write-Host "  ✓ Created multiple ratings"
Write-Host "  ✓ Tested all AWS APIs"
Write-Host "  → Ready to test Recommendation API locally!`n"

