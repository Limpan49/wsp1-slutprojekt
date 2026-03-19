require 'debug'
require "awesome_print"
require 'bcrypt'
require 'securerandom'

class App < Sinatra::Base
  enable :sessions
  configure do
    enable :sessions
    set :session_secret, SecureRandom.hex(64)
  end

  
    setup_development_features(self)

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
  
      erb :"threads/show"
      #erb :"category/show"
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
      redirect '/login' unless logged_in?
    
      db.execute(
        'INSERT INTO threads (title, category_id, user_id) VALUES (?, ?, ?)', 
        [params["title"], params["category_id"], current_user["id"]]
      )
    
      redirect "/categories/#{params["category_id"]}"
    end


    post '/threads/:id/posts' do |id|
      redirect '/login' unless logged_in?
    
      db.execute(
        'INSERT INTO posts (content, user_id, thread_id) VALUES (?, ?, ?)',
        [params["content"], current_user["id"], id]
      )
    
      redirect "/threads/#{id}"
    end

    get '/registrera' do
      erb :"users/registrera"
    end 

    post '/registrera' do 
      username = params[:username]
      password = BCrypt::Password.create(params[:password])

      db.execute(
        "INSERT INTO users (username, password_digest) VALUES (?, ?)", 
        [username, password]
      )

      redirect '/login'
    end 


    get '/login' do
      erb :"users/login"
    end
    
    post '/login' do
      user = db.execute(
        "SELECT * FROM users WHERE username = ?",
        [params[:username]]
      ).first
    
      if user && BCrypt::Password.new(user["password_digest"]) == params[:password]
        session[:user_id] = user["id"]
        redirect '/'
      else
        @error = "Fel användarnamn eller lösenord"
        erb :"users/login"
      end

      db.execute("DELETE FROME USERS WHERE")
    end
    
    get '/logout' do
      session.clear
      redirect '/'
    end

end
