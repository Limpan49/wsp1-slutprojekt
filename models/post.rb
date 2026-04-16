class Post
  def self.create(db, content, user_id, thread_id)
    db.execute(
      "INSERT INTO posts (content, user_id, thread_id) VALUES (?, ?, ?)",
      [content, user_id, thread_id]
    )
    db.last_insert_row_id
  end

  def self.categories(db, post_id)
    db.execute(
      "SELECT categories.* FROM categories
       JOIN post_categories ON categories.id = post_categories.category_id
       WHERE post_categories.post_id = ?",
      [post_id]
    )
  end
end
