package bookdetail

import (
	"net/http"

	"github.com/gin-gonic/gin"
)

type Handler struct {
	store Store
}

func NewHandler(s Store) *Handler { return &Handler{store: s} }

// =============================
// DTOs
// =============================

type BookDTO struct {
	WorkID  string   `json:"work_id"`
	Title   string   `json:"title"`
	Authors []string `json:"authors"`
	// TODO: Add more fields (subjects, description, covers, etc.) once schema is finalized.
}

type BatchIn struct {
	WorkIDs []string `json:"work_ids" binding:"required"`
}

// =============================
// Store Interface
// =============================
// Handlers depend on this interface only; swap implementations without changing handlers.
type Store interface {
	GetOne(id string) (BookDTO, bool, error)
	GetBatch(ids []string) ([]BookDTO, error)
}

// =============================
// Handlers
// =============================

// GET /books/:work_id
func (h *Handler) GetOne(c *gin.Context) {
	id := c.Param("work_id")
	if id == "" {
		c.JSON(http.StatusBadRequest, errJSON("invalid_id", "work_id is required"))
		return
	}
	item, ok, err := h.store.GetOne(id)
	if err != nil {
		c.JSON(http.StatusInternalServerError, errJSON("internal_error", err.Error()))
		return
	}
	if !ok {
		c.JSON(http.StatusNotFound, errJSON("not_found", "book not found"))
		return
	}
	c.JSON(http.StatusOK, item)
}

// POST /books/batch
func (h *Handler) PostBatch(c *gin.Context) {
	var req BatchIn
	if err := c.ShouldBindJSON(&req); err != nil || len(req.WorkIDs) == 0 {
		c.JSON(http.StatusBadRequest, errJSON("invalid_request", "work_ids is required"))
		return
	}
	items, err := h.store.GetBatch(req.WorkIDs)
	if err != nil {
		c.JSON(http.StatusInternalServerError, errJSON("internal_error", err.Error()))
		return
	}
	c.JSON(http.StatusOK, gin.H{"count": len(items), "items": items})
}

// =============================
// Helpers
// =============================

func errJSON(code, msg string) gin.H { return gin.H{"error": code, "message": msg} }