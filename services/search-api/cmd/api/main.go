package main

import (
	"log"
	"os"

	"search-api/internal/search"

	"github.com/gin-gonic/gin"
)

func main() {
	r := gin.Default()

	// Initialize store based on environment
	var store search.Store
	tableName := os.Getenv("DYNAMODB_TABLE_BOOKS")

	if tableName != "" {
		log.Printf("Using DynamoDB store with table: %s", tableName)
		var err error
		store, err = search.NewDynamoStore(tableName)
		if err != nil {
			log.Fatalf("Failed to create DynamoDB store: %v", err)
		}
	} else {
		log.Println("Using in-memory store (no DYNAMODB_TABLE_BOOKS env var)")
		store = search.NewMemStore()
	}

	// Create handler using the current store
	h := search.NewHandler(store)

	// Register routes
	r.POST("/search", h.PostSearch)
	r.POST("/search/advanced", h.PostAdvanced)
	r.GET("/search/shard/:prefix", h.GetShard)

	// Health check endpoint
	r.GET("/healthz", func(c *gin.Context) { c.String(200, "ok") })

	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	log.Printf("search-api listening on :%s", port)
	if err := r.Run(":" + port); err != nil {
		log.Fatal(err)
	}
}
