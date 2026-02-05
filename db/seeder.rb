require 'sqlite3'
require_relative '../config'

class Seeder
  def self.seed!
    puts "Using db file: #{DB_PATH}"
    drop_tables
    create_tables
    populate_tables
    puts "✅ Forum-databas seedad!"
  end

  def self.drop_tables
    db.execute("DROP TABLE IF EXISTS posts")
    db.execute("DROP TABLE IF EXISTS threads")
    db.execute("DROP TABLE IF EXISTS categories")
    db.execute("DROP TABLE IF EXISTS users")
  end

  def self.create_tables
    db.execute <<~SQL
      CREATE TABLE users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        username TEXT NOT NULL UNIQUE
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
        FOREIGN KEY(category_id) REFERENCES categories(id)
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
  end

  def self.populate_tables
    # Users
    db.execute("INSERT INTO users (username) VALUES ('Anonym123')")
    db.execute("INSERT INTO users (username) VALUES ('Flashbackarn')")

    # Categories
    db.execute("INSERT INTO categories (name) VALUES ('Politik')")
    db.execute("INSERT INTO categories (name) VALUES ('Datorer & IT')")

    # Threads
    db.execute("INSERT INTO threads (title, category_id) VALUES ('Valet 2026', 1)")
    db.execute("INSERT INTO threads (title, category_id) VALUES ('Bästa Linux-distron?', 2)")

    # Posts
    db.execute("INSERT INTO posts (content, user_id, thread_id)
                VALUES ('Det här valet blir intressant...', 1, 1)")
    db.execute("INSERT INTO posts (content, user_id, thread_id)
                VALUES ('Jag kör Arch btw', 2, 2)")
  end

  def self.db
    @db ||= SQLite3::Database.new(DB_PATH).tap do |db|
      db.results_as_hash = true
    end
  end
end

Seeder.seed!
