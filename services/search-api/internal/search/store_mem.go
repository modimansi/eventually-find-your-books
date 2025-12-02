package search

import "strings"

// memStore is a simple in-memory mock store for local testing.
// TODO: Replace this with a real data source (DynamoDB, Elasticsearch, etc.)
type memStore struct {
	data []BookDTO
}

func NewMemStore() Store {
	return &memStore{
		data: []BookDTO{
			{BookID: "OL1000046W", Title: "The Great Gatsby", Authors: []string{"F. Scott Fitzgerald"}},
			{BookID: "OL2000001W", Title: "Harry Potter and the Sorcerer's Stone", Authors: []string{"J.K. Rowling"}},
			{BookID: "OL3000002W", Title: "Hamlet", Authors: []string{"William Shakespeare"}},
			{BookID: "OL4000003W", Title: "Clean Architecture", Authors: []string{"Robert C. Martin"}},
		},
	}
}

// =============================
// Basic Search
// =============================

// Search performs a simple substring match on title or author.
func (m *memStore) Search(q string, limit int) ([]BookDTO, error) {
	q = strings.ToLower(q)
	out := make([]BookDTO, 0, limit)
	for _, b := range m.data {
		if containsFold(b.Title, q) || anyAuthorMatch(b.Authors, q) {
			out = append(out, b)
			if len(out) == limit {
				break
			}
		}
	}
	return out, nil
}

// SearchAdvanced filters by title and author.
func (m *memStore) SearchAdvanced(title, author string, subjects []string, limit int) ([]BookDTO, error) {
	title = strings.ToLower(strings.TrimSpace(title))
	author = strings.ToLower(strings.TrimSpace(author))
	out := make([]BookDTO, 0, limit)
	for _, b := range m.data {
		if (title == "" || containsFold(b.Title, title)) &&
			(author == "" || anyAuthorMatch(b.Authors, author)) {
			out = append(out, b)
			if len(out) == limit {
				break
			}
		}
	}
	return out, nil
}

// =============================
// OLD SHARDING (A–Z)
// =============================

// SearchShard returns results whose title starts with the given prefix.
func (m *memStore) SearchShard(prefix, q string, limit int) ([]BookDTO, error) {
	p := strings.ToUpper(prefix)
	q = strings.ToLower(q)
	out := make([]BookDTO, 0, limit)

	for _, b := range m.data {
		first := ""
		if b.Title != "" {
			first = strings.ToUpper(string([]rune(b.Title)[0]))
		}

		if first == p && (q == "" || containsFold(b.Title, q) || anyAuthorMatch(b.Authors, q)) {
			out = append(out, b)
			if len(out) == limit {
				break
			}
		}
	}
	return out, nil
}

// =============================
// NEW: Composite Sharding
// =============================

// SearchByShard routes a request to the correct composite shard.
// The rules here mirror the Python compute_shard_key() logic used
// when loading data into DynamoDB.
//
// Composite sharding model:
//
//   Hot letters (split into two shards using hashing):
//      A  -> A1, A2
//      S  -> S1, S2
//      T  -> T1, T2
//
//   Single-letter shards:
//      C, L, M, P
//
//   Multi-letter grouped shards:
//      BE       -> books starting with B or E
//      DJK      -> books starting with D, J, or K
//      FGQX     -> books starting with F, G, Q, or X
//      HIY      -> books starting with H, I, or Y
//      NOUVZ    -> books starting with N, O, U, V, or Z
//      RW       -> books starting with R or W
//
//   Fallback:
//      "0"      -> titles that do not begin with A–Z (rare)
//
// This allows local testing of the same shard grouping
// that exists inside DynamoDB's ShardIndex.
//
func (m *memStore) SearchByShard(shardKey, q string, limit int) ([]BookDTO, error) {
    shardKey = strings.ToUpper(shardKey)
    q = strings.ToLower(q)

    out := make([]BookDTO, 0, limit)

    if limit <= 0 {
        limit = 10
    }

    // Hot letters: two shards via hashing (A1/A2, S1/S2, T1/T2)
    if len(shardKey) == 2 && shardKey[1] >= '0' && shardKey[1] <= '9' {
        letter := shardKey[0:1]

        for _, b := range m.data {
            if b.Title == "" {
                continue
            }
            first := strings.ToUpper(string([]rune(b.Title)[0]))

            if first == letter && (q == "" || containsFold(b.Title, q) || anyAuthorMatch(b.Authors, q)) {
                out = append(out, b)
                if len(out) >= limit {
                    break
                }
            }
        }
        return out, nil
    }

    // Grouped shards
    shardToLetters := map[string]string{
        "C":     "C",
        "L":     "L",
        "M":     "M",
        "P":     "P",
        "BE":    "BE",
        "DJK":   "DJK",
        "FGQX":  "FGQX",
        "HIY":   "HIY",
        "NOUVZ": "NOUVZ",
        "RW":    "RW",
        "0":     "",
    }

    letters, ok := shardToLetters[shardKey]
    if !ok {
        // Unknown shard key -> empty result
        return out, nil
    }

    for _, b := range m.data {
        if b.Title == "" {
            continue
        }

        firstRune := []rune(b.Title)[0]
        firstUpper := strings.ToUpper(string(firstRune))

        // Special case: fallback "0" shard
        if shardKey == "0" {
            if firstUpper < "A" || firstUpper > "Z" {
                if q == "" || containsFold(b.Title, q) || anyAuthorMatch(b.Authors, q) {
                    out = append(out, b)
                    if len(out) >= limit {
                        break
                    }
                }
            }
            continue
        }

        // Grouped shard: match letters
        if strings.Contains(letters, firstUpper) &&
            (q == "" || containsFold(b.Title, q) || anyAuthorMatch(b.Authors, q)) {

            out = append(out, b)
            if len(out) >= limit {
                break
            }
        }
    }

    return out, nil
}

// =============================
// Helper functions
// =============================

func containsFold(s, sub string) bool { return strings.Contains(strings.ToLower(s), sub) }

func anyAuthorMatch(authors []string, needle string) bool {
	if needle == "" {
		return true
	}
	for _, a := range authors {
		if containsFold(a, needle) {
			return true
		}
	}
	return false
}