require 'sqlite3'
require_relative '../config' 
require 'bcrypt'


class Seeder
  def self.seed!
    drop_tables
    create_tables
    populate_tables
    puts "✅ Forum-databas seedad HALLÖÖ!"
  end

  def self.drop_tables
    db.execute("DROP TABLE IF EXISTS post_categories")
    db.execute("DROP TABLE IF EXISTS posts")
    db.execute("DROP TABLE IF EXISTS threads")
    db.execute("DROP TABLE IF EXISTS categories")
    db.execute("DROP TABLE IF EXISTS users")
  end

  def self.create_tables
    db.execute <<~SQL
      CREATE TABLE users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        username TEXT NOT NULL UNIQUE,
        password_digest TEXT NOT NULL
      );
    SQL

    db.execute <<~SQL
      CREATE TABLE categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL
      );
    SQL

    db.execute <<~SQL
      CREATE TABLE threads (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        category_id INTEGER,
        user_id INTEGER,
        FOREIGN KEY(category_id) REFERENCES categories(id),
        FOREIGN KEY(user_id) REFERENCES users(id)
      );
    SQL

    db.execute <<~SQL
      CREATE TABLE posts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        content TEXT NOT NULL,
        user_id INTEGER,
        thread_id INTEGER,
        FOREIGN KEY(user_id) REFERENCES users(id),
        FOREIGN KEY(thread_id) REFERENCES threads(id)
      );
    SQL

    db.execute <<~SQL
      CREATE TABLE post_categories (
        post_id INTEGER,
        category_id INTEGER,
        PRIMARY KEY (post_id, category_id),
        FOREIGN KEY(post_id) REFERENCES posts(id) ON DELETE CASCADE,
        FOREIGN KEY(category_id) REFERENCES categories(id) ON DELETE CASCADE
      );
    SQL
  end

  def self.populate_tables
    password = BCrypt::Password.create("1234")
    db.execute("INSERT INTO users (username, password_digest) VALUES (?, ?)", ["Flashbackarn", password])
    db.execute("INSERT INTO users (username, password_digest) VALUES (?, ?)", ["Anonym123", password])

    ["Samhälle & Politik", "Ekonomi", "Teknik", "Livsstil", "Nöje"].each do |name|
      db.execute("INSERT INTO categories (name) VALUES (?)", [name])
    end

    # Skapa en tråd
    db.execute("INSERT INTO threads (title, category_id, user_id) VALUES (?, ?, ?)", ["Valet 2026", 1, 1])
    
    # Skapa ett inlägg
    db.execute("INSERT INTO posts (content, user_id, thread_id) VALUES (?, ?, ?)", ["Det här valet blir spännande!", 1, 1])
    post_id = db.last_insert_row_id

    db.execute("INSERT INTO post_categories (post_id, category_id) VALUES (?, ?)", [post_id, 1]) 
    db.execute("INSERT INTO post_categories (post_id, category_id) VALUES (?, ?)", [post_id, 2]) 
  end

  def self.db
    @db ||= SQLite3::Database.new(DB_PATH).tap { |d| 
    d.results_as_hash = true }
  end
end

Seeder.seed!