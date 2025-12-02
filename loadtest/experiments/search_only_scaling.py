"""
Experiment: ALB P95 Latency vs Horizontal Scaling (Search-only workload)

Usage:
  locust -f loadtest/experiments/search_only_scaling.py \
    --host=http://book-alb-...elb.amazonaws.com \
    --headless --users 500 --step-load --step-users 50 --step-time 30s \
    --run-time 15m --html report.html --csv results
"""

from locust import HttpUser, task, constant
import random
import os

# 60% popular queries, 40% rare queries
POPULAR_QUERIES = [
    "Harry Potter",
    "The Hobbit",
    "The Lord of the Rings",
    "Percy Jackson",
    "Twilight",
    "The Hunger Games",
]

RARE_QUERIES = [
    "Godel Escher Bach",
    "Permutation City",
    "The Stars My Destination",
    "Lanark",
    "The Dispossessed",
    "Ubik",
    "A Canticle for Leibowitz",
    "Tigana",
    "The Book of the New Sun",
]


class SearchOnlyUser(HttpUser):
    """
    Each user: POST /search with no wait (thundering herd).
    Query mix: 60% popular, 40% rare.
    """

    host = os.getenv("LOCUST_HOST", "http://book-alb-dev-1967393761.us-west-2.elb.amazonaws.com")
    wait_time = constant(0)

    @task
    def search(self):
        query = random.choice(POPULAR_QUERIES) if random.random() < 0.6 else random.choice(RARE_QUERIES)
        self.client.post("/search", json={"query": query, "limit": 10}, name="/search")


