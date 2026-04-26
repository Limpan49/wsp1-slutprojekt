require 'debug'
require "awesome_print"
require 'bcrypt'
require 'securerandom'
require 'rack/utils'

require_relative 'models/user'
require_relative 'models/category'
require_relative 'models/forum_thread'
require_relative 'models/post'
require_relative 'models/post_category'

##
# Huvudklassen för Sinatra applikationen.
# Ansvarar för routing, sessions, autentisering,
# validering och säker rendering av användardata.
#
class App < Sinatra::Base
  enable :sessions

  configure do
    enable :sessions
    set :session_secret, SecureRandom.hex(64)
  end

  setup_development_features(self)

  # -------------------------------------------------------------------
  # DATABASE CONNECTION
  # -------------------------------------------------------------------

  ##
  # Skapar / återanvänder  SQLite databasanslutning
  #
  # @return [SQLite3::Database]
  #
  def db
    return @db if @db
    @db = SQLite3::Database.new(DB_PATH)
    @db.results_as_hash = true
    @db
  end

  # -------------------------------------------------------------------
  # HELPERS
  # -------------------------------------------------------------------

  helpers do
    ##
    # Hämtar den inloggade användaren med session.
    #
    # @return [Hash, nil]
    #
    def current_user
      return nil unless session[:user_id]
      User.find_by_id(db, session[:user_id])
    end

    ##
    # Kollar om användaren är inloggad.
    #
    # @return [Boolean]
    #
    def logged_in?
      !!current_user
    end

    ##
    # Escapear HTML för att förhindra XSS attacker.
    #
    # @param text [String]
    # @return [String] säker text
    #
    def h(text)
      Rack::Utils.escape_html(text.to_s)
    end
  end

  # -------------------------------------------------------------------
  # BEFORE BLOCK
  # -------------------------------------------------------------------

  ##
  # Körs innan varje route.
  # Laddar kategorier och nuvarande användare för att slippa upprepa kod.
  #
  before do
    @categories = Category.all(db)
    @current_user = current_user
  end

  # -------------------------------------------------------------------
  # ROUTES
  # -------------------------------------------------------------------

  ##
  # GET /
  # Startsidan
  #
  get '/' do
    erb :"index"
  end

  ##
  # GET /categories/:id
  # Visar kategori + trådar + inlägg
  #
  get '/categories/:id' do |id|
    @category = Category.find(db, id)
    @threads  = Category.threads(db, id)
    @posts    = Category.posts(db, id)
    erb :"category/show"
  end

  ##
  # GET /threads/:id
  # Visar en specifik tråd
  #
  get '/threads/:id' do |id|
    @thread = ForumThread.find(db, id)
    @posts  = ForumThread.posts(db, id)
    erb :"threads/show"
  end

  ##
  # GET /categories/:id/threads/new
  # Visar formulär för att skapa en ny tråd i en kategori.
  #
  get '/categories/:id/threads/new' do |id|
    @category_id = id
    erb :"threads/new"
  end

  ##
  # POST /threads
  # Skapar ny tråd + första inlägg
  #
  post '/threads' do
    redirect '/login' unless logged_in?

    category_id = params["category_id"]
    title       = params["title"]&.strip
    user_id     = current_user["id"]

    if title.nil? || title.empty?
      @error = "Titel får inte vara tom."
      @category_id = category_id
      return erb :"threads/new"
    end

    thread_id = ForumThread.create(db, title, category_id, user_id)
    post_id = Post.create(db, "Välkommen till tråden: #{title}", user_id, thread_id)

    PostCategory.add(db, post_id, category_id)

    redirect "/categories/#{category_id}"
  end

  ##
  # POST /threads/:id/posts
  # Skapar nytt inlägg i tråd
  #
  post '/threads/:id/posts' do |id|
    redirect '/login' unless logged_in?

    content = params["content"]&.strip

    if content.nil? || content.empty?
      @thread = ForumThread.find(db, id)
      @posts  = ForumThread.posts(db, id)
      @error  = "Inlägg får inte vara tomt."
      return erb :"threads/show"
    end

    post_id = Post.create(db, content, current_user["id"], id)

    if params["category_ids"]
      params["category_ids"].each do |cat_id|
        PostCategory.add(db, post_id, cat_id)
      end
    end

    redirect "/threads/#{id}"
  end

  ##
  # GET /registrera
  #
  get '/registrera' do
    erb :"users/registrera"
  end

  ##
  # POST /registrera
  # Skapar användare med validering
  #
  post '/registrera' do
    username = params[:username]&.strip
    password = params[:password]
    confirm  = params[:password_confirm]

    if username.nil? || username.empty?
      @error = "Användarnamn får inte vara tomt."
      return erb :"users/registrera"
    end

    if password.nil? || password.empty?
      @error = "Lösenord får inte vara tomt."
      return erb :"users/registrera"
    end

    if password != confirm
      @error = "Lösenorden matchar inte."
      return erb :"users/registrera"
    end

    if User.find_by_username(db, username)
      @error = "Användarnamnet är redan taget."
      return erb :"users/registrera"
    end

    password_digest = BCrypt::Password.create(password)
    User.create(db, username, password_digest)

    redirect '/login'
  end

  ##
  # GET /login
  #
  get '/login' do
    erb :"users/login"
  end

  ##
  # POST /login
  #
  post '/login' do
    if session[:cooldown_until] && Time.now < session[:cooldown_until]
      @error = "För många misslyckade försök. Försök igen om en stund."
      return erb :"users/login"
    end

    session[:login_attempts] ||= 0
    user = User.find_by_username(db, params[:username])

    # Okänt konto kanske 
    if user.nil?
      session[:login_attempts] += 1

      if session[:login_attempts] >= 3
        session[:cooldown_until] = Time.now + 30
        return erb :'users/förmångaförsök'
      end

      @error = "Kontot finns inte"
      return erb :"users/login"
    end

    # Fel lösenord
    unless BCrypt::Password.new(user["password_digest"]) == params[:password]
      session[:login_attempts] += 1

      if session[:login_attempts] >= 3
        session[:cooldown_until] = Time.now + 30
        return erb :'users/förmångaförsök'
      end

      @error = "Fel lösenord"
      return erb :"users/login"
    end

    # Lyckad inloggning dvs återställ
    session[:login_attempts] = 0
    session[:cooldown_until] = nil
    session[:user_id] = user["id"]

    redirect '/'
  end

  ##
  # GET /logout
  #
  get '/logout' do
    session.clear
    redirect '/'
  end

  ##
  # GET /users/tabort
  #
  get '/users/tabort' do
    redirect '/login' unless logged_in?
    erb :"users/tabort"
  end

  ##
  # DELETE /users/:id
  # Tar bort användare
  #
  delete '/users/:id' do |id|
    redirect '/login' unless logged_in?
    halt 403 unless current_user["id"].to_i == id.to_i

    User.delete(db, id)
    session.clear
    redirect '/'
  end

  ##
  # PATCH /users/:id/password
  # Uppdaterar lösenord
  #
  patch '/users/:id/password' do |id|
    redirect '/login' unless logged_in?
    halt 403 unless current_user["id"].to_i == id.to_i

    nuvarande = params[:nuvarande_losenord]
    nytt      = params[:nytt_losenord]
    bekräfta  = params[:bekrafta_nytt]

    if nuvarande.to_s.empty? || nytt.to_s.empty? || bekräfta.to_s.empty?
      @error = "Alla fält måste fyllas i."
      return erb :"users/tabort"
    end

    unless BCrypt::Password.new(current_user["password_digest"]) == nuvarande
      @error = "Nuvarande lösenord är fel"
      return erb :"users/tabort"
    end

    unless nytt == bekräfta
      @error = "Nya lösenorden matchar inte."
      return erb :"users/tabort"
    end

    nytt_hash = BCrypt::Password.create(nytt)
    User.update_password(db, id, nytt_hash)

    @success = "Lösenordet har uppdaterats!"
    erb :"users/tabort"
  end

  # -------------------------------------------------------------------
  # LEGACY ROUUTES
  # -------------------------------------------------------------------

  ##
  # POST /users/:id/tabort
  #
  post '/users/:id/tabort' do |id|
    redirect '/login' unless logged_in?
    halt 403 unless current_user["id"].to_i == id.to_i

    User.delete(db, id)
    session.clear
    redirect '/'
  end

  ##
  # POST /users/:id/update_password
  #
  post '/users/:id/update_password' do |id|
    redirect '/login' unless logged_in?
    halt 403 unless current_user["id"].to_i == id.to_i

    nuvarande = params[:nuvarande_losenord]
    nytt      = params[:nytt_losenord]
    bekräfta  = params[:bekrafta_nytt]

    unless BCrypt::Password.new(current_user["password_digest"]) == nuvarande
      @error = "Nuvarande lösenord är fel"
      return erb :"users/tabort"
    end

    unless nytt == bekräfta
      @error = "Nya lösenorden matchar inte"
      return erb :"users/tabort"
    end

    nytt_hash = BCrypt::Password.create(nytt)
    User.update_password(db, id, nytt_hash)

    @success = "Lösenordet har uppdaterats!"
    erb :"users/tabort"
  end
end
