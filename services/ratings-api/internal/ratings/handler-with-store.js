// Handler that works with any store implementation
class RatingsHandler {
    constructor(store) {
        this.store = store;
    }

    rateBook = async (req, res) => {
        const { book_id } = req.params;
        const { user_id, rating } = req.body;

        if (!user_id || !rating || rating < 1 || rating > 5) {
            return res.status(400).json({ error: "Invalid input" });
        }

        try {
            await this.store.rateBook(book_id, user_id, rating);
            res.status(201).json({ message: "Rating added successfully" });
        } catch (error) {
            console.error("Error rating book:", error);
            res.status(500).json({ error: "Internal server error" });
        }
    };

    getBookRatings = async (req, res) => {
        const { book_id } = req.params;

        try {
            const ratings = await this.store.getBookRatings(book_id);
            
            if (!ratings || ratings.length === 0) {
                return res.status(404).json({ error: "No ratings found for book" });
            }

            res.json(ratings);
        } catch (error) {
            console.error("Error getting book ratings:", error);
            res.status(500).json({ error: "Internal server error" });
        }
    };

    getUserRatings = async (req, res) => {
        const { user_id } = req.params;

        try {
            const ratings = await this.store.getUserRatings(user_id);

            if (!ratings || ratings.length === 0) {
                return res.status(404).json({ error: "No ratings found for user" });
            }

            res.json(ratings);
        } catch (error) {
            console.error("Error getting user ratings:", error);
            res.status(500).json({ error: "Internal server error" });
        }
    };
}

module.exports = RatingsHandler;

