package bookdetail

// memStore is a simple in-memory mock for local testing.
// TODO: Replace with a real data source (DynamoDB, PostgreSQL, etc.).
// TODO: Optionally wrap with a Redis cache layer (Cache-Aside) once DB is in place.
type memStore struct {
	data map[string]BookDTO
}

func NewMemStore() Store {
	return &memStore{
		data: map[string]BookDTO{
			"OL1000046W": {BookID: "OL1000046W", Title: "The Great Gatsby", Authors: []string{"F. Scott Fitzgerald"}},
			"OL2000001W": {BookID: "OL2000001W", Title: "Harry Potter and the Sorcerer's Stone", Authors: []string{"J. K. Rowling"}},
			"OL3000002W": {BookID: "OL3000002W", Title: "Hamlet", Authors: []string{"William Shakespeare"}},
			"OL4000003W": {BookID: "OL4000003W", Title: "Clean Architecture", Authors: []string{"Robert C. Martin"}},
		},
	}
}

func (m *memStore) GetOne(id string) (BookDTO, bool, error) {
	// TODO: Implement DB read here in a real store (key lookup by book_id).
	b, ok := m.data[id]
	return b, ok, nil
}

func (m *memStore) GetBatch(ids []string) ([]BookDTO, error) {
	// TODO: Implement DB batch read here in a real store (BatchGet / IN query).
	out := make([]BookDTO, 0, len(ids))
	for _, id := range ids {
		if b, ok := m.data[id]; ok {
			out = append(out, b)
		}
	}
	return out, nil
}
