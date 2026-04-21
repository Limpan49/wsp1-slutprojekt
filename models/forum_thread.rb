class ForumThread
  def self.find(db, id)
    db.execute("SELECT * FROM threads WHERE id = ?", [id]).first
  end

  def self.create(db, title, category_id, user_id)
    db.execute(
      "INSERT INTO threads (title, category_id, user_id) VALUES (?, ?, ?)",
      [title, category_id, user_id]
    )
    db.last_insert_row_id
  end

  def self.posts(db, thread_id)
    db.execute("SELECT * FROM posts WHERE thread_id = ?", [thread_id])
  end
end
