const ratingsData = {};

exports.rateBook = (req, res) => {
    const { book_id } = req.params;
    const { user_id, rating } = req.body;

    if (!user_id || !rating || rating < 1 || rating > 5) {
        return res.status(400).json({ error: "Invalid input" });
    }

    if (!ratingsData[book_id]) {
        ratingsData[book_id] = [];
    }

    ratingsData[book_id].push({ user_id, rating });
    res.status(201).json({ message: "Rating added successfully" });
};

exports.getBookRatings = (req, res) => {
    const { book_id } = req.params;
    const bookRatings = ratingsData[book_id];

    if (!bookRatings) {
        return res.status(404).json({ error: "Book not found" });
    }

    res.json(bookRatings);
};

exports.getUserRatings = (req, res) => {
    const { user_id } = req.params;
    const userRatings = [];

    for (const ratings of Object.values(ratingsData)) {
        for (const rating of ratings) {
            if (rating.user_id === user_id) {
                userRatings.push(rating);
            }
        }
    }

    if (userRatings.length === 0) {
        return res.status(404).json({ error: "No ratings found for user" });
    }

    res.json(userRatings);
};
