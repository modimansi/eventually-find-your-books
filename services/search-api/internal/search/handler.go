package search

import (
	"net/http"
	"strings"
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
	// TODO: Add more fields (subjects, description, etc.) once the database schema is finalized.
}

// =============================
// Store Interface
// =============================
// This defines the persistence layer contract.
// The handlers only depend on this interface, so the implementation can be swapped freely.
type Store interface {
	Search(q string, limit int) ([]BookDTO, error)
	SearchAdvanced(title, author string, subjects []string, limit int) ([]BookDTO, error)
	SearchShard(prefix, q string, limit int) ([]BookDTO, error)
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
