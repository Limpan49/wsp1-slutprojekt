class ForumThread
  def self.find(db, id)
    db.execute("SELECT * FROM threads WHERE id = ?", [id]).first
  end

  def self.create(db, title, category_id, user_id)
    db.execute(
      "INSERT INTO threads (title, category_id, user_id) VALUES (?, ?, ?)",
      [title, category_id, user_id]
    )
  end

  def self.posts(db, id)
    db.execute(<<~SQL, [id])
      SELECT posts.id, posts.content, users.username
      FROM posts
      JOIN users ON posts.user_id = users.id
      WHERE posts.thread_id = ?
      ORDER BY posts.id ASC
    SQL
  end
end
