class User
  def self.find_by_id(db, id)
    db.execute("SELECT * FROM users WHERE id = ?", [id]).first
  end

  def self.find_by_username(db, username)
    db.execute("SELECT * FROM users WHERE username = ?", [username]).first
  end

  def self.create(db, username, password_digest)
    db.execute(
      "INSERT INTO users (username, password_digest) VALUES (?, ?)",
      [username, password_digest]
    )
  end

  def self.delete(db, id)
    db.execute("DELETE FROM users WHERE id = ?", [id])
  end
  
  def self.update_password(db, id, new_digest)
    db.execute("UPDATE users SET password_digest = ? WHERE id = ?", [new_digest, id])
  end
end


