const { DynamoDBClient } = require("@aws-sdk/client-dynamodb");
const { DynamoDBDocumentClient, PutCommand, GetCommand, QueryCommand } = require("@aws-sdk/lib-dynamodb");

class DynamoDBStore {
    constructor(tableName, region = "us-west-2") {
        const client = new DynamoDBClient({ region });
        this.docClient = DynamoDBDocumentClient.from(client);
        this.tableName = tableName;
    }

    async rateBook(bookId, userId, rating) {
        const params = {
            TableName: this.tableName,
            Item: {
                user_id: userId,
                book_id: bookId,
                rating: rating,
                timestamp: new Date().toISOString()
            }
        };

        try {
            await this.docClient.send(new PutCommand(params));
            return { success: true, message: "Rating added successfully" };
        } catch (error) {
            console.error("Error adding rating:", error);
            throw new Error(`Failed to add rating: ${error.message}`);
        }
    }

    async getBookRatings(bookId) {
        const params = {
            TableName: this.tableName,
            IndexName: "BookRatingsIndex",
            KeyConditionExpression: "book_id = :bookId",
            ExpressionAttributeValues: {
                ":bookId": bookId
            }
        };

        try {
            const result = await this.docClient.send(new QueryCommand(params));
            return result.Items || [];
        } catch (error) {
            console.error("Error getting book ratings:", error);
            throw new Error(`Failed to get ratings: ${error.message}`);
        }
    }

    async getUserRatings(userId) {
        const params = {
            TableName: this.tableName,
            KeyConditionExpression: "user_id = :userId",
            ExpressionAttributeValues: {
                ":userId": userId
            }
        };

        try {
            const result = await this.docClient.send(new QueryCommand(params));
            return result.Items || [];
        } catch (error) {
            console.error("Error getting user ratings:", error);
            throw new Error(`Failed to get user ratings: ${error.message}`);
        }
    }
}

module.exports = DynamoDBStore;

