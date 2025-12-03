Search Sharding Experiment Report

This README documents the sharding experiment comparing three architectures in the Search API:

- Architecture A: Single worker baseline
- Architecture B: 26-way naive sharded aggregator
- Architecture C: Composite sharded aggregator (new feature)

The purpose is to measure throughput, latency, and validate parallel speedup beahavior.

Sections:
 - ECS task configurations for each architecture
 - Locust load-test commands
 - CSV output parsed values

--------------------------- 

Section :: Architecture A -- Single Worker Baseline

Endpoint:
post /search

Only 1 ECS task, performs a full DynamoDB can.

TERFAORM Configuration:
search_api_desired_count  = 1
search_api_min_count      = 1
search_api_max_count      = 1
search_api_cpu          = 1024
search_api_memory        = 2048

Locust command:

ARCH=A \
locust -f loadtest/experiments/search_sharded_amdahl_experiment.py \\
  --host=http://book-alb-dev-1462726070.us-west-2.elb.amazonaws.com \\
  --headless -users 1 --spawn-rate 1 --run-time 120s \\
  --html loadtest/results/search_amdahl_A_single.html \\
  --csv  loadtest/results/search_amdahl_A_single

---------------------------

Section :: Architecture B -- 26-Way Naive Sharded Aggregator

Endpoint:
get /search/sharded

Uniformly fanz out to 26 shards (A--Z).

TERFAORM Configuration:
search_api_desired_count = 26
search_api_min_count    = 26
search_api_max_count    = 26
search_api_cpu        = 1024
search_api_memory       = 2048

Locust command:

ARCH=B \
locust -f loadtest/experiments/search_sharded_amdahl_experiment.py \\
  --host=http://book-alb-dev-1462726070.us-west-2.elb.amazonaws.com \\
  --headless -users 200 --spawn-rate 200 --run-time 8m \\
  --html loadtest/results/search_amdahl_B_sharded_8m.html \\
  --csv  loadtest/results/search_amdahl_B_sharded_8m

---------------------------

Section :: Architecture C -- Composite Sharded Aggregator (16 Logical Shards)

Endpoint:
get /search/composite_sharded

Uses 26 physical tasks but only 16 logical shards at the aggregator stage.

Hot shards split (T-1,T-2).
Cold shards grouped (BE, FGQX, HIY).

Terraform configuration:
search_api_desired_count = 26
search_api_min_count    = 26
search_api_max_count    = 26
search_api_cpu         = 1024
search_api_memory        = 2048

Locust command:

ARCH=C \
locust -f loadtest/experiments/search_sharded_amdahl_experiment.py \\
  --host=http://book-alb-dev-1462726070.us-west-2.elb.amazonaws.com \\
  --headless -users 200 --spawn-rate 200 --run-time 8m \\
  --html loadtest/results/search_amdahl_C_composite_8m.html \\
  --csv  loadtest/results/search_amdahl_C_composite_8m

------------------------- 

Traffic Mix used:

// 50% single word querys
- neght

// 30% multi-word
- "Nightmare on Wall Street"

// 20% author
- "Martin Mayer"

--------------------------
/Phase Timings Verification for Sharded Architectures/

For Architecture B:

# times; shows delays for each shard request

for i in {1..30}; do;
  curl -s -D - "$ALB/search/sharded?query=night&limit=10" -o /dev/null
    | grep -E \"X-Phase-Parse|X-Phase-Fanout|X-Phase-Aggregate\";
done

Architecture C has an identical script using /search/composite_sharded instead.

-------------------------

CSV Results Summary for Report generation:

architecure A:
 p50 = 620 ms
 p95 = 3500 ms
 RPS = 0.26
 error% = 0

architecure B:
 p50 = 87 ms
 p95 = 180 ms
 RPS = 95.1 
 error% = 0

architecure C:
 p50 = 93 ms 
 p95 = 150 ms 
 RPS = 95.4
 error% = 0

--------------------------

End of File
