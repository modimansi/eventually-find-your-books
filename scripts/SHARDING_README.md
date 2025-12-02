\# Search API — Sharding Guide

This document explains how to use both the old A–Z sharding and the new composite sharding.

Before testing, export your ALB DNS:

\`\`\`bash
export ALB="http://book-alb-dev-2069299573.us-west-2.elb.amazonaws.com"
\`\`\`

---

\#\# 1\. Basic Search

**Endpoint**

\`\`\`
POST /search
\`\`\`

**Example**

\`\`\`bash
curl -s -X POST "\$ALB/search" \
  -H "Content-Type: application/json" \
  -d '{"query":"ready","limit":3}' | jq
\`\`\`

---

\#\# 2\. Old Sharding (A–Z Prefix)

Old sharding uses DynamoDB GSI: **TitlePrefixIndex** on `title_prefix`.

**Endpoint**

\`\`\`
GET /search/shard/:prefix
\`\`\`

- `:prefix` must be a single A–Z letter  
- Optional: `query`, `limit`

**Examples**

\`\`\`bash
curl -s "\$ALB/search/shard/R?limit=5" | jq
\`\`\`

\`\`\`bash
curl -s "\$ALB/search/shard/R?query=ready&limit=5" | jq
\`\`\`

---

\#\# 3\. New Composite Sharding

Composite sharding uses:

- DynamoDB attribute: **shard_key**
- GSI: **ShardIndex**

---

\#\#\# 3\.1 Shard Groups

**Hot letters — split into 2 each**

| Letter | Shards |
|--------|--------|
| A      | A1, A2 |
| S      | S1, S2 |
| T      | T1, T2 |

**Balanced grouped shards**

| Shard Key | Letters |
|-----------|---------|
| C         | C       |
| L         | L       |
| M         | M       |
| P         | P       |
| BE        | B, E    |
| DJK       | D, J, K |
| FGQX      | F, G, Q, X |
| HIY       | H, I, Y |
| NOUVZ     | N, O, U, V, Z |
| RW        | R, W    |
| 0         | Non-A–Z |

---

\#\#\# 3\.2 Endpoint

\`\`\`
GET /search/composite/:shard
\`\`\`

\#\#\# 3\.3 Examples

\`\`\`bash
curl -s "\$ALB/search/composite/A1?limit=5" | jq
\`\`\`

\`\`\`bash
curl -s "\$ALB/search/composite/A2?limit=5" | jq
\`\`\`

\`\`\`bash
curl -s "\$ALB/search/composite/BE?limit=5" | jq
\`\`\`

\`\`\`bash
curl -s "\$ALB/search/composite/RW?limit=5" | jq
\`\`\`

**Keyword Search inside shard**

\`\`\`bash
curl -s "\$ALB/search/composite/FGQX?query=game&limit=5" | jq
\`\`\`

---

\#\# 4\. Test All Shards Automatically

\`\`\`bash
for shard in A1 A2 S1 S2 T1 T2 C L M P BE DJK FGQX HIY NOUVZ RW 0; do
  echo "===== Shard \$shard ====="
  curl -s "\$ALB/search/composite/\$shard?limit=3" | jq '.count'
done
\`\`\`

---

\#\# 5\. Verify DynamoDB Table Contains 50k Rows

\`\`\`bash
aws dynamodb scan \
  --table-name book-recommendation-books-dev \
  --select COUNT \
  --region us-west-2
\`\`\`

Expected:

\`\`\`
Count: 50000
\`\`\`

---

\#\# 6\. Summary

- `/search` → full-table filtered search  
- `/search/shard/:prefix` → old A–Z prefix sharding  
- `/search/composite/:shard` → new composite sharding  
- Uses shard_key + ShardIndex for fast queries  
- Hot letters split, cold letters grouped  