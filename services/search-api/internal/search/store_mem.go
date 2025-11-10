package search

import "strings"

// memStore is a simple in-memory mock store for local testing.
// TODO: Replace this with a real data source (Elasticsearch, DynamoDB, PostgreSQL, etc.)
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

// Search performs a simple substring match on title or author.
// TODO: Replace with a full-text search using a real search engine (Elasticsearch, OpenSearch, etc.)
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
// TODO: Add more filters (subjects, genre, etc.) when supported by the database.
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

// SearchShard returns results whose title starts with the given prefix.
// TODO: When running in distributed mode, this should route to the correct shard worker (e.g., "H" shard ECS task).
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
// Helper functions
// =============================

// Case-insensitive substring match
func containsFold(s, sub string) bool { return strings.Contains(strings.ToLower(s), sub) }

// Checks if any author name matches the search term
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
