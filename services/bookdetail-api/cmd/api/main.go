package main

import (
	"log"

	"bookdetail-api/internal/bookdetail"

	"github.com/gin-gonic/gin"
)

func main() {
	r := gin.Default()

	// In-memory store for now.
	// TODO: Replace with a real database implementation (DynamoDB, PostgreSQL, etc.).
	store := bookdetail.NewMemStore()

	// Create handler using the current store.
	h := bookdetail.NewHandler(store)

	// Register routes.
	r.GET("/books/:book_id", h.GetOne)
	r.POST("/books/batch", h.PostBatch)

	// Health check endpoint.
	r.GET("/healthz", func(c *gin.Context) { c.String(200, "ok") })

	log.Println("bookdetail-api listening on :8081")
	if err := r.Run(":8081"); err != nil {
		log.Fatal(err)
	}
}
