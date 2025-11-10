// In-memory store implementation (for testing)
class MemoryStore {
    constructor() {
        this.ratingsData = {};
    }

    async rateBook(bookId, userId, rating) {
        if (!this.ratingsData[bookId]) {
            this.ratingsData[bookId] = [];
        }

        this.ratingsData[bookId].push({ 
            user_id: userId, 
            book_id: bookId,
            rating,
            timestamp: new Date().toISOString()
        });

        return { success: true, message: "Rating added successfully" };
    }

    async getBookRatings(bookId) {
        return this.ratingsData[bookId] || [];
    }

    async getUserRatings(userId) {
        const userRatings = [];

        for (const [bookId, ratings] of Object.entries(this.ratingsData)) {
            for (const rating of ratings) {
                if (rating.user_id === userId) {
                    userRatings.push({ ...rating, book_id: bookId });
                }
            }
        }

        return userRatings;
    }
}

module.exports = MemoryStore;

