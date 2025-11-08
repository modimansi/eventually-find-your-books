package main

import (
	"log"

	"github.com/gin-gonic/gin"
	"search-api/internal/search"
)

func main() {
	r := gin.Default()

	// In-memory store for now.
	// TODO: Replace with a real database implementation later (Elasticsearch, DynamoDB, PostgreSQL, etc.)
	store := search.NewMemStore()

	// Create handler using the current store
	h := search.NewHandler(store)

	// Register routes
	r.POST("/search", h.PostSearch)
	r.POST("/search/advanced", h.PostAdvanced)
	r.GET("/search/shard/:prefix", h.GetShard)

	// Health check endpoint
	r.GET("/healthz", func(c *gin.Context) { c.String(200, "ok") })

	log.Println("search-api listening on :8080")
	if err := r.Run(":8080"); err != nil {
		log.Fatal(err)
	}
}