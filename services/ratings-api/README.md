# Ratings API

This API allows users to rate books, retrieve all ratings for a book, and get a user’s rating history.

## Endpoints

- `POST /books/{book_id}/rate`: Rate a book (1-5 stars) with `{ "user_id": "user_001", "rating": 5 }`.
- `GET /books/{book_id}/ratings`: Get all ratings for a specific book.
- `GET /users/{user_id}/ratings`: Get the rating history of a specific user.
- `GET /healthz`: Health check endpoint (returns 200 OK).

## Setup

1. Install dependencies:

   ```bash
   npm install
   ```

2. Start the server:

   ```bash
   npm start
   ```

The server will run on port 3000 by default.
