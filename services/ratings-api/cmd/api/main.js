const express = require('express');
const app = express();
const ratingsHandler = require('../../internal/ratings/handler');

app.use(express.json());

app.post('/books/:book_id/rate', ratingsHandler.rateBook);
app.get('/books/:book_id/ratings', ratingsHandler.getBookRatings);
app.get('/users/:user_id/ratings', ratingsHandler.getUserRatings);

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
