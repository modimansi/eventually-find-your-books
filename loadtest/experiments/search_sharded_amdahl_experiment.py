"""
Amdahl's Law Experiment for Search:
- Architecture A (single worker): POST /search
- Architecture B (26-way sharded aggregator): GET /search/sharded?query=...

Traffic mix (1000 total searches typical):
- 50% single word: "Gatsby", "Tolkien"
- 30% multi-word: "The Great Gatsby"
- 20% author: "J.K. Rowling"

Usage (headless, 15m):
  locust -f loadtest/experiments/search_sharded_amdahl_experiment.py \
    --host=http://book-alb-dev-1967393761.us-west-2.elb.amazonaws.com \
    --headless --users 200 --spawn-rate 200 --run-time 15m \
    --html loadtest/results/search_amdahl_single.html \
    --csv  loadtest/results/search_amdahl_single
  # Switch endpoints using ARCH=B to hit /search/sharded
"""

from locust import HttpUser, task, constant
import os
import random

ARCH = os.getenv("ARCH", "A")  # "A" -> /search (single), "B" -> /search/sharded (fan-out)

SINGLE_WORD = ["Gatsby", "Tolkien"]
MULTI_WORD = ["The Great Gatsby"]
AUTHOR = ["J.K. Rowling"]

def pick_query():
    r = random.random()
    if r < 0.5:
        return random.choice(SINGLE_WORD)
    elif r < 0.8:
        return random.choice(MULTI_WORD)
    else:
        return random.choice(AUTHOR)

class SearchAmdahlUser(HttpUser):
    host = os.getenv("LOCUST_HOST", "http://book-alb-dev-1967393761.us-west-2.elb.amazonaws.com")
    wait_time = constant(2.0)  # per spec

    @task
    def do_search(self):
        q = pick_query()
        if ARCH == "B":
            # Sharded aggregator
            self.client.get(f"/search/sharded?query={q}&limit=10", name="/search/sharded")
        else:
            # Single-worker search (full table scan path)
            self.client.post("/search", json={"query": q, "limit": 10}, name="/search")


