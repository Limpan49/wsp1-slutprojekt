class PostCategory
  def self.add(db, post_id, category_id)
    db.execute(
      "INSERT INTO post_categories (post_id, category_id) VALUES (?, ?)",
      [post_id, category_id]
    )
  end
end
