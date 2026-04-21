class Category
  def self.all(db)
    db.execute("SELECT * FROM categories")
  end

  def self.find(db, id)
    db.execute("SELECT * FROM categories WHERE id = ?", [id]).first
  end

  def self.threads(db, id)
    db.execute("SELECT * FROM threads WHERE category_id = ? ORDER BY id DESC", [id])
  end

  def self.posts(db, category_id)
    db.execute(<<~SQL, [category_id])
      SELECT posts.*, users.username, threads.title
      FROM posts
      JOIN post_categories ON posts.id = post_categories.post_id
      JOIN users ON posts.user_id = users.id
      JOIN threads ON posts.thread_id = threads.id
      WHERE post_categories.category_id = ?
      ORDER BY posts.id DESC
    SQL
  end  
end

