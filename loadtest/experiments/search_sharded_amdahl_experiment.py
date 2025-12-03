"""
Architectures:
- Architecture A (single worker, baseline):
    POST /search
- Architecture B (26-way sharded aggregator, naive A–Z):
    GET /search/sharded?query=...
- Architecture C (26 workers, 16-way composite sharded aggregator):
    GET /search/composite_sharded?query=...

Traffic mix (per 1000 searches, approximate) – all based on the same book:
Book:  "Nightmare on Wall Street"
Author:"Martin Mayer"

- 50% single word search:
    "Nightmare"
- 30% multi-word search:
    "Nightmare on Wall Street"
- 20% author search:
    "Martin Mayer"

Usage (headless, 15m, from repo root):

  # Architecture A (single worker, /search), search_api_desired_count=1
  ARCH=A \
  locust -f loadtest/experiments/search_sharded_amdahl_experiment.py \
    --host=http://book-alb-dev-1967393761.us-west-2.elb.amazonaws.com \
    --headless --users 200 --spawn-rate 200 --run-time 15m \
    --html loadtest/results/search_amdahl_single.html \
    --csv  loadtest/results/search_amdahl_single

  # Architecture B (26-way naive sharded, /search/sharded),
  # search_api_desired_count=26
  ARCH=B \
  locust -f loadtest/experiments/search_sharded_amdahl_experiment.py \
    --host=http://book-alb-dev-1967393761.us-west-2.elb.amazonaws.com \
    --headless --users 200 --spawn-rate 200 --run-time 15m \
    --html loadtest/results/search_amdahl_sharded_26.html \
    --csv  loadtest/results/search_amdahl_sharded_26

  # Architecture C (26 workers, 16-way composite sharded, /search/composite_sharded),
  # search_api_desired_count=26
  ARCH=C \
  locust -f loadtest/experiments/search_sharded_amdahl_experiment.py \
    --host=http://book-alb-dev-1967393761.us-west-2.elb.amazonaws.com \
    --headless --users 200 --spawn-rate 200 --run-time 15m \
    --html loadtest/results/search_amdahl_composite_16.html \
    --csv  loadtest/results/search_amdahl_composite_16

You can also override LOCUST_HOST instead of using --host, e.g.:

  ARCH=C LOCUST_HOST=http://book-alb-dev-1967393761.us-west-2.elb.amazonaws.com locust ...
"""

from locust import HttpUser, task, constant
import os
import random

# ARCH:
#   A -> POST /search                  (single worker baseline)
#   B -> GET  /search/sharded          (26-way naive sharded)
#   C -> GET  /search/composite_sharded (16-way composite sharded)
ARCH = os.getenv("ARCH", "A").upper()

# All queries are based on:
#   Title : Nightmare on Wall Street
#   Author: Martin Mayer
SINGLE_WORD = ["night"]
MULTI_WORD = ["Nightmare on Wall Street"]
AUTHOR = ["Martin Mayer"]


def pick_query() -> str:
    """Return a query following the 50/30/20 mix."""
    r = random.random()
    if r < 0.5:
        # 50% single word
        return random.choice(SINGLE_WORD)
    elif r < 0.8:
        # next 30% multi-word
        return random.choice(MULTI_WORD)
    else:
        # last 20% author
        return random.choice(AUTHOR)


class SearchAmdahlUser(HttpUser):
    # LOCUST_HOST can override this; otherwise CLI --host will be used
    host = os.getenv(
        "LOCUST_HOST",
        "http://book-alb-dev-1967393761.us-west-2.elb.amazonaws.com",
    )
    # Per spec: 2s wait time between user actions
    wait_time = constant(2.0)

    @task
    def do_search(self):
        q = pick_query()

        if ARCH == "B":
            # Architecture B: naive 26-way sharded aggregator
            self.client.get(
                f"/search/sharded?query={q}&limit=10",
                name="/search/sharded",
            )
        elif ARCH == "C":
            # Architecture C: 16-way composite sharded aggregator
            self.client.get(
                f"/search/composite_sharded?query={q}&limit=10",
                name="/search/composite_sharded",
            )
        else:
            # Architecture A: single-worker search (full scan path)
            self.client.post(
                "/search",
                json={"query": q, "limit": 10},
                name="/search",
            )