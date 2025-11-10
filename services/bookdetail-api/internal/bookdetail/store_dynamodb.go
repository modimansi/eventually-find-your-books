package bookdetail

import (
	"context"
	"fmt"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/feature/dynamodb/attributevalue"
	"github.com/aws/aws-sdk-go-v2/service/dynamodb"
	"github.com/aws/aws-sdk-go-v2/service/dynamodb/types"
)

// DynamoDB store implementation
type dynamoStore struct {
	client    *dynamodb.Client
	tableName string
}

// NewDynamoStore creates a new DynamoDB-backed store
func NewDynamoStore(tableName string) (Store, error) {
	cfg, err := config.LoadDefaultConfig(context.TODO())
	if err != nil {
		return nil, fmt.Errorf("unable to load AWS config: %w", err)
	}

	client := dynamodb.NewFromConfig(cfg)

	return &dynamoStore{
		client:    client,
		tableName: tableName,
	}, nil
}

// Book represents the full DynamoDB book structure
type Book struct {
	BookID           string   `dynamodbav:"book_id"`
	Title            string   `dynamodbav:"title"`
	TitleLower       string   `dynamodbav:"title_lower"`
	TitlePrefix      string   `dynamodbav:"title_prefix"`
	Authors          []Author `dynamodbav:"authors"`
	ISBN13           []string `dynamodbav:"isbn_13"`
	FirstPublishYear *int     `dynamodbav:"first_publish_year"`
	Subjects         []string `dynamodbav:"subjects"`
	Language         string   `dynamodbav:"language"`
	AvgRating        float64  `dynamodbav:"avg_rating"`
	RatingCount      int      `dynamodbav:"rating_count"`
	Description      string   `dynamodbav:"description"`
	CoverID          *int64   `dynamodbav:"cover_id"`
}

// Author represents a book author
type Author struct {
	AuthorID   string `dynamodbav:"author_id"`
	AuthorName string `dynamodbav:"author_name"`
}

// ToDTO converts a Book to BookDTO
func (b *Book) ToDTO() BookDTO {
	authors := make([]string, len(b.Authors))
	for i, author := range b.Authors {
		authors[i] = author.AuthorName
	}
	return BookDTO{
		BookID:  b.BookID,
		Title:   b.Title,
		Authors: authors,
	}
}

// GetOne retrieves a single book by ID
func (d *dynamoStore) GetOne(id string) (BookDTO, bool, error) {
	ctx := context.TODO()

	input := &dynamodb.GetItemInput{
		TableName: aws.String(d.tableName),
		Key: map[string]types.AttributeValue{
			"book_id": &types.AttributeValueMemberS{Value: id},
		},
	}

	result, err := d.client.GetItem(ctx, input)
	if err != nil {
		return BookDTO{}, false, fmt.Errorf("failed to get item: %w", err)
	}

	if result.Item == nil {
		return BookDTO{}, false, nil
	}

	var book Book
	err = attributevalue.UnmarshalMap(result.Item, &book)
	if err != nil {
		return BookDTO{}, false, fmt.Errorf("failed to unmarshal item: %w", err)
	}

	return book.ToDTO(), true, nil
}

// GetBatch retrieves multiple books by IDs
func (d *dynamoStore) GetBatch(ids []string) ([]BookDTO, error) {
	if len(ids) == 0 {
		return []BookDTO{}, nil
	}

	ctx := context.TODO()

	// Build keys for batch get
	keys := make([]map[string]types.AttributeValue, len(ids))
	for i, id := range ids {
		keys[i] = map[string]types.AttributeValue{
			"book_id": &types.AttributeValueMemberS{Value: id},
		}
	}

	input := &dynamodb.BatchGetItemInput{
		RequestItems: map[string]types.KeysAndAttributes{
			d.tableName: {
				Keys: keys,
			},
		},
	}

	result, err := d.client.BatchGetItem(ctx, input)
	if err != nil {
		return nil, fmt.Errorf("failed to batch get items: %w", err)
	}

	items, ok := result.Responses[d.tableName]
	if !ok || len(items) == 0 {
		return []BookDTO{}, nil
	}

	books := []Book{}
	err = attributevalue.UnmarshalListOfMaps(items, &books)
	if err != nil {
		return nil, fmt.Errorf("failed to unmarshal items: %w", err)
	}

	// Convert to DTOs
	out := make([]BookDTO, len(books))
	for i, book := range books {
		out[i] = book.ToDTO()
	}

	return out, nil
}
