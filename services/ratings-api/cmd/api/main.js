const express = require('express');
const app = express();

// Import handler and stores
const RatingsHandler = require('../../internal/ratings/handler-with-store');
const MemoryStore = require('../../internal/ratings/store-memory');
const DynamoDBStore = require('../../internal/ratings/store-dynamodb');

app.use(express.json());

// Initialize store based on environment
let store;
const tableName = process.env.DYNAMODB_TABLE_RATINGS;

if (tableName) {
    console.log(`Using DynamoDB store with table: ${tableName}`);
    store = new DynamoDBStore(tableName, process.env.AWS_REGION || 'us-west-2');
} else {
    console.log('Using in-memory store (no DYNAMODB_TABLE_RATINGS env var)');
    store = new MemoryStore();
}

// Create handler with the store
const handler = new RatingsHandler(store);

// Register routes
app.post('/books/:book_id/rate', handler.rateBook);
app.get('/books/:book_id/ratings', handler.getBookRatings);
app.get('/users/:user_id/ratings', handler.getUserRatings);

// Health check endpoint
app.get('/healthz', (req, res) => {
    res.status(200).send('ok');
});

app.use((req, res, next) => {
    res.status(404).json({ error: "Not found" });
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
    console.log(`Server running on port ${PORT}`);
});
