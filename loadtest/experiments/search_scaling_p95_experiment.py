"""
Search API Horizontal Scaling Experiment (P95 vs task count)

Goal:
- Measure p95 latency as we horizontally scale Search tasks: 2 → 5 → 10
- Traffic: 50 → 500 users ramp over 5 minutes, then sustain to 15 minutes total
- Each user: POST /search (60% popular, 40% rare), wait 2s, repeat

Usage (example headless run):
  locust -f loadtest/experiments/search_scaling_p95_experiment.py \
    --host=http://book-alb-dev-1967393761.us-west-2.elb.amazonaws.com \
    --headless --users 500 --step-load --step-users 50 --step-time 30s \
    --run-time 15m --html report.html --csv results
"""

from locust import HttpUser, task, constant
import random
import os

# 60% popular, 40% rare queries
POPULAR_QUERIES = [
    "Harry Potter", "The Hobbit", "The Lord of the Rings",
    "Percy Jackson", "Twilight", "The Hunger Games",
    "Game of Thrones", "Dune", "The Witcher", "Ender's Game",
]

RARE_QUERIES = [
    "Permutation City", "The Dispossessed", "Ubik",
    "A Canticle for Leibowitz", "Anathem", "Lanark",
    "The Stars My Destination", "Tigana", "Riddley Walker",
    "The Three-Body Problem",
]


class SearchScalingUser(HttpUser):
    """
    Each user posts /search with 60/40 popular/rare query mix.
    Wait time of 2s between iterations to simulate steady users.
    """
    host = os.getenv("LOCUST_HOST", "http://book-alb-dev-905356730.us-west-2.elb.amazonaws.com")
    wait_time = constant(2.0)

    @task
    def search(self):
        query = random.choice(POPULAR_QUERIES) if random.random() < 0.6 else random.choice(RARE_QUERIES)
        self.client.post("/search", json={"query": query, "limit": 10}, name="/search")


