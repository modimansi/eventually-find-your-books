package search

import (
	"context"
	"fmt"
	"strings"

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

// Search performs a scan with filter (not ideal for production, but works for small datasets)
func (d *dynamoStore) Search(query string, limit int) ([]BookDTO, error) {
	ctx := context.TODO()

	// For better performance, use Query with TitleLowerIndex GSI
	// For now, we'll do a simple scan with filter
	q := strings.ToLower(query)

	input := &dynamodb.ScanInput{
		TableName: aws.String(d.tableName),
		Limit:     aws.Int32(int32(limit * 3)), // Get more items to filter
	}

	result, err := d.client.Scan(ctx, input)
	if err != nil {
		return nil, fmt.Errorf("failed to scan table: %w", err)
	}

	books := []Book{}
	err = attributevalue.UnmarshalListOfMaps(result.Items, &books)
	if err != nil {
		return nil, fmt.Errorf("failed to unmarshal items: %w", err)
	}

	// Filter in memory (for simplicity)
	out := make([]BookDTO, 0, limit)
	for _, b := range books {
		authorNames := make([]string, len(b.Authors))
		for i, a := range b.Authors {
			authorNames[i] = a.AuthorName
		}
		if containsFold(b.Title, q) || anyAuthorMatch(authorNames, q) {
			out = append(out, b.ToDTO())
			if len(out) >= limit {
				break
			}
		}
	}

	return out, nil
}

// SearchAdvanced performs advanced search
func (d *dynamoStore) SearchAdvanced(title, author string, subjects []string, limit int) ([]BookDTO, error) {
	ctx := context.TODO()

	input := &dynamodb.ScanInput{
		TableName: aws.String(d.tableName),
		Limit:     aws.Int32(int32(limit * 3)),
	}

	result, err := d.client.Scan(ctx, input)
	if err != nil {
		return nil, fmt.Errorf("failed to scan table: %w", err)
	}

	books := []Book{}
	err = attributevalue.UnmarshalListOfMaps(result.Items, &books)
	if err != nil {
		return nil, fmt.Errorf("failed to unmarshal items: %w", err)
	}

	// Filter
	title = strings.ToLower(strings.TrimSpace(title))
	author = strings.ToLower(strings.TrimSpace(author))

	out := make([]BookDTO, 0, limit)
	for _, b := range books {
		authorNames := make([]string, len(b.Authors))
		for i, a := range b.Authors {
			authorNames[i] = a.AuthorName
		}
		if (title == "" || containsFold(b.Title, title)) &&
			(author == "" || anyAuthorMatch(authorNames, author)) {
			out = append(out, b.ToDTO())
			if len(out) >= limit {
				break
			}
		}
	}

	return out, nil
}

// SearchShard searches by title prefix using GSI
func (d *dynamoStore) SearchShard(prefix, query string, limit int) ([]BookDTO, error) {
	ctx := context.TODO()

	p := strings.ToUpper(prefix)

	// Use TitlePrefixIndex GSI
	input := &dynamodb.QueryInput{
		TableName:              aws.String(d.tableName),
		IndexName:              aws.String("TitlePrefixIndex"),
		KeyConditionExpression: aws.String("title_prefix = :prefix"),
		ExpressionAttributeValues: map[string]types.AttributeValue{
			":prefix": &types.AttributeValueMemberS{Value: p},
		},
		Limit: aws.Int32(int32(limit * 2)),
	}

	result, err := d.client.Query(ctx, input)
	if err != nil {
		return nil, fmt.Errorf("failed to query index: %w", err)
	}

	books := []Book{}
	err = attributevalue.UnmarshalListOfMaps(result.Items, &books)
	if err != nil {
		return nil, fmt.Errorf("failed to unmarshal items: %w", err)
	}

	// Filter by query if provided
	q := strings.ToLower(query)
	out := make([]BookDTO, 0, limit)
	for _, b := range books {
		authorNames := make([]string, len(b.Authors))
		for i, a := range b.Authors {
			authorNames[i] = a.AuthorName
		}
		if q == "" || containsFold(b.Title, q) || anyAuthorMatch(authorNames, q) {
			out = append(out, b.ToDTO())
			if len(out) >= limit {
				break
			}
		}
	}

	return out, nil
}
