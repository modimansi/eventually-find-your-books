package search

import (
	"fmt"
	"net/http"
	"strings"
	"time"
	"unicode/utf8"

	"github.com/gin-gonic/gin"
)

type Handler struct {
	store Store
}

func NewHandler(s Store) *Handler { return &Handler{store: s} }

// =============================
// Data Transfer Objects (DTOs)
// =============================

type SearchReq struct {
	Query string `json:"query" binding:"required"`
	Limit int    `json:"limit"`
}

type AdvancedReq struct {
	Title   string   `json:"title"`
	Author  string   `json:"author"`
	Subject []string `json:"subject"`
	Limit   int      `json:"limit"`
}

type BookDTO struct {
	BookID  string   `json:"book_id"`
	Title   string   `json:"title"`
	Authors []string `json:"authors"`
}

// =============================
// Store Interface
// =============================
// Add SearchByShard for composite sharding
type Store interface {
	Search(q string, limit int) ([]BookDTO, error)
	SearchAdvanced(title, author string, subjects []string, limit int) ([]BookDTO, error)
	SearchShard(prefix, q string, limit int) ([]BookDTO, error)

	// NEW: composite shard search (shard_key)
	SearchByShard(shardKey, q string, limit int) ([]BookDTO, error) // NEW
}

// =============================
// Handlers Implementation
// =============================

// POST /search
func (h *Handler) PostSearch(c *gin.Context) {
	var req SearchReq
	if err := c.ShouldBindJSON(&req); err != nil || strings.TrimSpace(req.Query) == "" {
		c.JSON(http.StatusBadRequest, errJSON("invalid_request", "query is required"))
		return
	}
	limit := defLimit(req.Limit)
	items, err := h.store.Search(req.Query, limit)
	if err != nil {
		c.JSON(http.StatusInternalServerError, errJSON("internal_error", err.Error()))
		return
	}
	c.JSON(http.StatusOK, gin.H{"count": len(items), "items": items})
}

// POST /search/advanced
func (h *Handler) PostAdvanced(c *gin.Context) {
	var req AdvancedReq
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, errJSON("invalid_request", "bad json"))
		return
	}
	limit := defLimit(req.Limit)
	items, err := h.store.SearchAdvanced(req.Title, req.Author, req.Subject, limit)
	if err != nil {
		c.JSON(http.StatusInternalServerError, errJSON("internal_error", err.Error()))
		return
	}
	c.JSON(http.StatusOK, gin.H{"count": len(items), "items": items})
}

// =============================
// OLD SHARDING: /search/shard/:prefix
// (single letter A–Z)
// =============================

// GET /search/shard/:prefix
func (h *Handler) GetShard(c *gin.Context) {
	prefix := c.Param("prefix")
	q := c.Query("query")
	limit := parseLimit(c.Query("limit"), 20)

	if utf8.RuneCountInString(prefix) != 1 {
		c.JSON(http.StatusBadRequest, errJSON("invalid_prefix", "prefix must be a single letter"))
		return
	}

	items, err := h.store.SearchShard(prefix, q, limit)
	if err != nil {
		c.JSON(http.StatusInternalServerError, errJSON("internal_error", err.Error()))
		return
	}

	c.JSON(http.StatusOK, gin.H{"count": len(items), "items": items})
}

// =============================
// NEW: COMPOSITE SHARDING
// e.g. /search/composite/T1
//      /search/composite/I-M
// =============================

// GET /search/composite/:shard
func (h *Handler) GetCompositeShard(c *gin.Context) {
	shardKey := c.Param("shard")
	q := c.Query("query")
	limit := parseLimit(c.Query("limit"), 20)

	if shardKey == "" {
		c.JSON(http.StatusBadRequest, errJSON("invalid_shard", "shard key required"))
		return
	}

	items, err := h.store.SearchByShard(shardKey, q, limit)
	if err != nil {
		c.JSON(http.StatusInternalServerError, errJSON("internal_error", err.Error()))
		return
	}

	c.JSON(http.StatusOK, gin.H{"count": len(items), "items": items})
}

// =============================
// NEW: SHARDED AGGREGATOR
// GET /search/sharded?query=...&limit=...
// Fans out to 26 shards (A–Z) in parallel using SearchShard
// Adds phase timing headers: X-Phase-Parse, X-Phase-Fanout, X-Phase-Aggregate (ms)
// =============================

// GET /search/sharded
func (h *Handler) GetSharded(c *gin.Context) {
	start := nowMs()
	q := strings.TrimSpace(c.Query("query"))
	limit := parseLimit(c.Query("limit"), 20)
	parseDone := nowMs()

	if q == "" {
		c.JSON(http.StatusBadRequest, errJSON("invalid_request", "query is required"))
		return
	}

	type shardResp struct {
		items []BookDTO
		err   error
	}

	results := make(chan shardResp, 26)
	letters := "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
	for i := 0; i < len(letters); i++ {
		prefix := string(letters[i])
		go func(pref string) {
			items, err := h.store.SearchShard(pref, q, limit)
			results <- shardResp{items: items, err: err}
		}(prefix)
	}

	all := make([]BookDTO, 0, limit*2)
	for i := 0; i < 26; i++ {
		r := <-results
		if r.err != nil {
			// continue on error; aggregator remains best-effort
			continue
		}
		all = append(all, r.items...)
	}
	fanoutDone := nowMs()

	// Deduplicate by BookID and trim to limit
	seen := make(map[string]struct{}, len(all))
	out := make([]BookDTO, 0, limit)
	for _, b := range all {
		if _, ok := seen[b.BookID]; ok {
			continue
		}
		seen[b.BookID] = struct{}{}
		out = append(out, b)
		if len(out) >= limit {
			break
		}
	}

	aggregateDone := nowMs()

	c.Header("X-Phase-Parse", msToHeader(parseDone-start))
	c.Header("X-Phase-Fanout", msToHeader(fanoutDone-parseDone))
	c.Header("X-Phase-Aggregate", msToHeader(aggregateDone-fanoutDone))
	c.JSON(http.StatusOK, gin.H{"count": len(out), "items": out})
}

// =============================
// Helper functions
// =============================

func defLimit(n int) int {
	if n <= 0 {
		return 20
	}
	return n
}

func parseLimit(s string, d int) int {
	n := 0
	for _, r := range s {
		if r < '0' || r > '9' {
			return d
		}
		n = n*10 + int(r-'0')
	}
	if n <= 0 {
		return d
	}
	return n
}

func errJSON(code, msg string) gin.H { return gin.H{"error": code, "message": msg} }

// simple millis using std time
func nowMs() int64 { return time.Now().UnixNano() / 1e6 }

func msToHeader(ms int64) string {
	if ms < 0 {
		ms = 0
	}
	return fmt.Sprintf("%d", ms)
}