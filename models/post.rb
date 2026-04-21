class Post
  def self.create(db, content, user_id, thread_id)
    db.execute(
      "INSERT INTO posts (content, user_id, thread_id) VALUES (?, ?, ?)",
      [content, user_id, thread_id]
    )

    db.last_insert_row_id
  end

  def self.find(db, id)
    db.execute("SELECT * FROM posts WHERE id = ?", [id]).first
  end

  def self.posts_for_thread(db, thread_id)
    db.execute("SELECT * FROM posts WHERE thread_id = ?", [thread_id])
  end
end
