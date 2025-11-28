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
	BookID      string   `dynamodbav:"book_id"`
	Title       string   `dynamodbav:"title"`
	TitleLower  string   `dynamodbav:"title_lower"`
	TitlePrefix string   `dynamodbav:"title_prefix"`

	// NEW: composite shard key (T1, A2, I-M, R-U, etc.)
	ShardKey string `dynamodbav:"shard_key"` // NEW FIELD

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

// ============================================================================
// Basic search: full table scan + in-memory filter.
// OK for ~50k items and keeps behaviour simple and correct.
// ============================================================================

func (d *dynamoStore) Search(query string, limit int) ([]BookDTO, error) {
    ctx := context.TODO()

    q := strings.ToLower(strings.TrimSpace(query))
    if q == "" {
        return []BookDTO{}, nil
    }
    if limit <= 0 {
        limit = 20
    }

    out := make([]BookDTO, 0, limit)
    var lastKey map[string]types.AttributeValue

    for {
        input := &dynamodb.ScanInput{
            TableName: aws.String(d.tableName),
        }
        if lastKey != nil {
            input.ExclusiveStartKey = lastKey
        }

        result, err := d.client.Scan(ctx, input)
        if err != nil {
            return nil, fmt.Errorf("failed to scan table: %w", err)
        }

        if len(result.Items) == 0 {
            break
        }

        books := []Book{}
        if err := attributevalue.UnmarshalListOfMaps(result.Items, &books); err != nil {
            return nil, fmt.Errorf("failed to unmarshal items: %w", err)
        }

        for _, b := range books {
            authorNames := make([]string, len(b.Authors))
            for i, a := range b.Authors {
                authorNames[i] = a.AuthorName
            }

            if containsFold(b.Title, q) || anyAuthorMatch(authorNames, q) {
                out = append(out, b.ToDTO())
                if len(out) >= limit {
                    return out, nil
                }
            }
        }

        if len(result.LastEvaluatedKey) == 0 {
            break
        }
        lastKey = result.LastEvaluatedKey
    }

    return out, nil
}

// ============================================================================
// Advanced search: Scan + in-memory filter (your original logic)
// ============================================================================

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
	if err := attributevalue.UnmarshalListOfMaps(result.Items, &books); err != nil {
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

// ============================================================================
// Old sharding: /search/shard/{prefix} using single-letter TitlePrefixIndex
// ============================================================================

// SearchShard searches by title prefix using GSI (single-letter shard: A–Z)
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
	if err := attributevalue.UnmarshalListOfMaps(result.Items, &books); err != nil {
		return nil, fmt.Errorf("failed to unmarshal items: %w", err)
	}

	// Filter by query if provided (same logic as basic search)
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

// ============================================================================
// NEW: Composite sharding: /search/shard/{shardKey} using ShardIndex
// ============================================================================

// SearchByShard queries books within a composite shard (shard_key)
// and optionally filters by a substring of title_lower.
func (d *dynamoStore) SearchByShard(shardKey, query string, limit int) ([]BookDTO, error) {
	ctx := context.TODO()

	if limit <= 0 {
		limit = 10
	}

	// Base query on ShardIndex
	exprValues := map[string]types.AttributeValue{
		":sk": &types.AttributeValueMemberS{Value: shardKey},
	}

	input := &dynamodb.QueryInput{
		TableName:              aws.String(d.tableName),
		IndexName:              aws.String("ShardIndex"), // NEW GSI name
		KeyConditionExpression: aws.String("shard_key = :sk"),
		ExpressionAttributeValues: exprValues,
		Limit: aws.Int32(int32(limit * 2)),
	}

	// Optional filter on title_lower
	if query != "" {
		q := strings.ToLower(query)
		input.FilterExpression = aws.String("contains(title_lower, :q)")
		exprValues[":q"] = &types.AttributeValueMemberS{Value: q}
	}

	result, err := d.client.Query(ctx, input)
	if err != nil {
		return nil, fmt.Errorf("query shard %s: %w", shardKey, err)
	}

	if len(result.Items) == 0 {
		return []BookDTO{}, nil
	}

	books := []Book{}
	if err := attributevalue.UnmarshalListOfMaps(result.Items, &books); err != nil {
		return nil, fmt.Errorf("failed to unmarshal shard items: %w", err)
	}

	out := make([]BookDTO, 0, limit)
	for _, b := range books {
		out = append(out, b.ToDTO())
		if len(out) >= limit {
			break
		}
	}

	return out, nil
}