require 'debug'
require "awesome_print"

class App < Sinatra::Base

    setup_development_features(self)

    # Funktion för att prata med databasen
    # Exempel på användning: db.execute('SELECT * FROM fruits')

    
    
    def db
      return @db if @db
      @db = SQLite3::Database.new(DB_PATH)
      @db.results_as_hash = true

      return @db
    end

    helpers do
      def current_user
        return nil unless session[:user_id]
        db.execute("SELECT * FROM users WHERE id = ?", [session[:user_id]]).first
      end

      def logged_in?
        !!current_user
      end
    end

    # Routen /

    get '/' do
      @categories = db.execute('SELECT * FROM categories')
      erb :"index"
    end

    #Categories 

    get '/categories/:id' do |id|
      @category = db.execute(
        'SELECT * FROM categories WHERE id = ?', [id]
      ).first
  
      @threads = db.execute(
        'SELECT * FROM threads WHERE category_id = ? ORDER BY id DESC', [id]
      )
  
      erb :"categories/show"
    end

    #Threads 

    get '/threads/:id' do |id|
      @thread = db.execute(
        'SELECT * FROM threads WHERE id = ?', [id]
      ).first
  
      @posts = db.execute(<<~SQL, [id])
        SELECT posts.content, users.username
        FROM posts
        JOIN users ON posts.user_id = users.id
        WHERE posts.thread_id = ?
        ORDER BY posts.id ASC
      SQL
  
      erb :"threads/show"
    end


    get '/categories/:id/threads/new' do |id|
      @category_id = id
      erb :"threads/new"
    end


    post '/threads' do 
      title = params["title"]
      category_id = params["category_id"]

      db.execute(
        'INSERT INTO threads (title, category_id) VALUES (?, ?)', 
        [title, category_id]
      )

      redirect "/categories/#{category_id}"
    end 



    post '/threads/:id/posts' do id 
      content = params["content"]

      db.execute(
        'INSERT INTO posts (content, user_id, thread_id) VALUES (?, ?, ?)',
        [content, 1, id]
      )
      redirect "/threads/#{id}"
    end 


    get '/registrera' do
      erb :"users/registrera"
    end 

    post '/registrera' do 
      require 'bcrypt'

      username = params[:username]
      password = BCrypt::Password.create(params[:password])

      db.execute(
        "INSERT INTO users (username, password_digest) VALUES (?, ?)", 
        [username, password]
      )

      redirect '/login'
    end 

end
