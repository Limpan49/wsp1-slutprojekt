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
end
