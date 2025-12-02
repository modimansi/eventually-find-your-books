"""
Recommendation API Cache TTL Experiment

Goal:
- Compare performance under three cache configurations:
  A) No cache (intentionally broken/invalid REDIS_URL)
  B) 5-minute TTL
  C) 60-minute TTL

Traffic Model:
- 250 concurrent users over 20 minutes
- 80% of traffic from a "top" set of 10 heavy users
- 20% of traffic from a long-tail of many users
- Each virtual user repeatedly calls: GET /recommendations/{user_id}?limit={LIMIT}
- Wait time between requests is constant to keep the arrival rate predictable

Usage (headless example):
  locust -f loadtest/experiments/reco_cache_ttl_experiment.py \
    --host=http://<alb-dns-or-url> \
    --headless --users 250 --spawn-rate 50 --run-time 20m \
    --html loadtest/results/reco_cache_ttl_5m.html \
    --csv  loadtest/results/reco_cache_ttl_5m

Env overrides (optional):
  RECO_LIMIT=5
  TOP_USERS=user1,user2,user3,user4,user5,user6,user7,user8,user9,user10
  LONG_TAIL_COUNT=1000
  USER_PREFIX=user
  TOP_TRAFFIC_SHARE=0.8
  WAIT_SECONDS=2
"""

from locust import HttpUser, task, constant
import os
import random


def _env(name: str, default: str) -> str:
    val = os.getenv(name)
    return val if val not in (None, "") else default


RECO_LIMIT = int(_env("RECO_LIMIT", "5"))
TOP_USERS = [u for u in _env("TOP_USERS", "user1,user2,user3,user4,user5,user6,user7,user8,user9,user10").split(",") if u]
LONG_TAIL_COUNT = int(_env("LONG_TAIL_COUNT", "1000"))
USER_PREFIX = _env("USER_PREFIX", "user")
TOP_TRAFFIC_SHARE = float(_env("TOP_TRAFFIC_SHARE", "0.8"))
WAIT_SECONDS = float(_env("WAIT_SECONDS", "0"))

# Build long-tail users as user11..user(10+LONG_TAIL_COUNT)
LONG_TAIL_USERS = [f"{USER_PREFIX}{i}" for i in range(len(TOP_USERS) + 1, len(TOP_USERS) + LONG_TAIL_COUNT + 1)]


class RecommendationsUser(HttpUser):
    """
    Sends GET /recommendations/{user_id}?limit={RECO_LIMIT}
    80% of requests target "TOP_USERS" (hot keys), 20% target "LONG_TAIL_USERS" (cold/rare).
    """

    host = os.getenv("LOCUST_HOST", "http://book-alb-dev-1967393761.us-west-2.elb.amazonaws.com")
    wait_time = constant(WAIT_SECONDS)

    @task
    def get_recommendations(self):
        if random.random() < TOP_TRAFFIC_SHARE and TOP_USERS:
            user_id = random.choice(TOP_USERS)
        else:
            # Guard in case LONG_TAIL_USERS is empty in a custom env
            candidate_pool = LONG_TAIL_USERS or TOP_USERS
            user_id = random.choice(candidate_pool)

        self.client.get(f"/recommendations/{user_id}?limit={RECO_LIMIT}", name="/recommendations/:user_id")


