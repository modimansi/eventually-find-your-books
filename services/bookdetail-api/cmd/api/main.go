package main

import (
	"log"
	"os"

	"bookdetail-api/internal/bookdetail"

	"github.com/gin-gonic/gin"
)

func main() {
	r := gin.Default()

	// Initialize store based on environment
	var store bookdetail.Store
	tableName := os.Getenv("DYNAMODB_TABLE_BOOKS")

	if tableName != "" {
		log.Printf("Using DynamoDB store with table: %s", tableName)
		var err error
		store, err = bookdetail.NewDynamoStore(tableName)
		if err != nil {
			log.Fatalf("Failed to create DynamoDB store: %v", err)
		}
	} else {
		log.Println("Using in-memory store (no DYNAMODB_TABLE_BOOKS env var)")
		store = bookdetail.NewMemStore()
	}

	// Create handler using the current store.
	h := bookdetail.NewHandler(store)

	// Register routes.
	r.GET("/books/:book_id", h.GetOne)
	r.POST("/books/batch", h.PostBatch)

	// Health check endpoint.
	r.GET("/healthz", func(c *gin.Context) { c.String(200, "ok") })

	port := os.Getenv("PORT")
	if port == "" {
		port = "8081"
	}

	log.Printf("bookdetail-api listening on :%s", port)
	if err := r.Run(":" + port); err != nil {
		log.Fatal(err)
	}
}
