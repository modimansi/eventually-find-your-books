"""
Locust Load Testing for Book Recommendation System
Run: locust -f loadtest/locustfile.py --host=http://book-alb-dev-552414421.us-west-2.elb.amazonaws.com
Then open: http://localhost:8089
"""

from locust import HttpUser, task, between
import random

# Sample book IDs from your dataset
BOOK_IDS = [
    "OL15936512W", "OL5092623W", "OL1975714W", "OL2707183W", 
    "OL17062644W", "OL5961784W", "OL16509148W", "OL19347273W"
]

# Sample search queries
SEARCH_QUERIES = [
    "Ready Player One", "Mrs. Frisby and the Rats of Nimh", "A Fire upon the Deep",
    "Grave Peril", "The Song of Achilles", "The City of Ember (The First Book of Ember)",
    "The Tales of Beedle the Bard", "To Kill a Mockingbird", "The Hobbit"
]

# Sample users for ratings
USER_IDS = [f"user{i}" for i in range(1, 101)]


class BookSystemUser(HttpUser):
    """Simulates a user browsing and interacting with the book system"""
    
    # Wait between 1-3 seconds between tasks (realistic user behavior)
    wait_time = between(1, 3)
    
    @task(3)  # Weight 3 - most common action
    def search_books(self):
        """Search for books by query"""
        query = random.choice(SEARCH_QUERIES)
        self.client.post("/search", json={
            "query": query,
            "limit": random.randint(5, 20)
        }, name="/search")
    
    @task(2)  # Weight 2 - common action
    def get_book_details(self):
        """Get details of a specific book"""
        book_id = random.choice(BOOK_IDS)
        self.client.get(f"/books/{book_id}", name="/books/:book_id")
    
    @task(1)  # Weight 1 - less common
    def rate_book(self):
        """Rate a book"""
        book_id = random.choice(BOOK_IDS)
        user_id = random.choice(USER_IDS)
        rating = random.randint(1, 5)
        
        self.client.post(f"/books/{book_id}/rate", json={
            "user_id": user_id,
            "rating": rating
        }, name="/books/:book_id/rate")
    
    @task(1)
    def get_book_ratings(self):
        """Get ratings for a book"""
        book_id = random.choice(BOOK_IDS)
        self.client.get(f"/books/{book_id}/ratings", name="/books/:book_id/ratings")
    
    @task(1)
    def get_user_ratings(self):
        """Get all ratings by a user"""
        user_id = random.choice(USER_IDS)
        self.client.get(f"/users/{user_id}/ratings", name="/users/:user_id/ratings")
    
    @task(2)
    def batch_get_books(self):
        """Batch get multiple book details"""
        book_ids = random.sample(BOOK_IDS, random.randint(2, 5))
        self.client.post("/books/batch", json={
            "book_ids": book_ids
        }, name="/books/batch")
    
    @task(1)
    def advanced_search(self):
        """Advanced search with filters"""
        queries = ["Harry", "Lord", "Game", "Pride", "Hobbit"]
        self.client.post("/search/advanced", json={
            "title": random.choice(queries),
            "min_year": random.randint(1950, 2000),
            "max_year": 2024,
            "limit": random.randint(10, 30)
        }, name="/search/advanced")
    
    @task(1)
    def shard_search(self):
        """Autocomplete-style prefix search"""
        prefixes = ["HAR", "LOR", "GAM", "TWI", "HUN", "PRI"]
        prefix = random.choice(prefixes)
        self.client.get(f"/search/shard/{prefix}?limit=10", 
                       name="/search/shard/:prefix")


class HeavyUser(HttpUser):
    """Simulates a heavy user with rapid requests (stress test)"""
    
    wait_time = between(0.1, 0.5)  # Very fast - aggressive load
    
    @task
    def rapid_search(self):
        query = random.choice(SEARCH_QUERIES)
        self.client.post("/search", json={"query": query, "limit": 10})
    
    @task
    def rapid_book_detail(self):
        book_id = random.choice(BOOK_IDS)
        self.client.get(f"/books/{book_id}")

