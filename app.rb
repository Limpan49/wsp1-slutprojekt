require 'debug'
require "awesome_print"
require 'bcrypt'
require 'securerandom'

require_relative 'models/user'
require_relative 'models/category'
require_relative 'models/forum_thread'
require_relative 'models/post'
require_relative 'models/post_category'

##
# Huvudklassen för Sinatra applikationen.
# Hanterar routing, sessions, autentisering och rendering av views.
#
class App < Sinatra::Base
  försök = 3
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
  # Öppnar en SQLite databasanslutning.
  #
  # @return [SQLite3::Database] aktiv databasanslutning
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
    # Hämtar den inloggade användaren baserat på session[:user_id].
    #
    # @return [Hash, nil] användarens databaspost eller nil om ingen är inloggad
    #
    def current_user
      return nil unless session[:user_id]
      User.find_by_id(db, session[:user_id])
    end

    ##
    # Kontrollerar om en användare är inloggad.
    #
    # @return [Boolean] true om användaren är inloggad
    #
    def logged_in?
      !!current_user
    end
  end

  # -------------------------------------------------------------------
  # BEFORE BLOCK (DRY)
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
  #
  # Visar startsidan med alla kategorier.
  #
  # @return [ERB] index sidan
  #
  get '/' do
    erb :"index"
  end

  ##
  # GET /categories/:id
  #
  # Visar en kategori, dess trådar och alla inlägg kopplade via post_categories.
  #
  # @param id [Integer] kategori-ID
  # @return [ERB] kategori sidan
  #
  get '/categories/:id' do |id|
    @category = Category.find(db, id)
    @threads  = Category.threads(db, id)
    @posts    = Category.posts(db, id)
    erb :"category/show"
  end

  ##
  # GET /threads/:id
  #
  # Visar en tråd och alla dess inlägg.
  #
  # @param id [Integer] tråd-ID
  # @return [ERB] tråd sidan
  #
  get '/threads/:id' do |id|
    @thread = ForumThread.find(db, id)
    @posts  = ForumThread.posts(db, id)
    erb :"threads/show"
  end

  ##
  # GET /categories/:id/threads/new
  #
  # Visar formulär för att skapa en ny tråd i en kategori.
  #
  # @param id [Integer] kategori ID
  # @return [ERB] formulärsidan
  #
  get '/categories/:id/threads/new' do |id|
    @category_id = id
    erb :"threads/new"
  end

  ##
  # POST /threads
  #
  # Skapar en ny tråd och ett första inlägg.
  #
  # @return [Redirect] redirect till kategorisidan
  #
  post '/threads' do
    redirect '/login' unless logged_in?

    category_id = params["category_id"]
    title       = params["title"]
    user_id     = current_user["id"]

    thread_id = ForumThread.create(db, title, category_id, user_id)
    post_id   = Post.create(db, "Välkommen till tråden: #{title}", user_id, thread_id)

    PostCategory.add(db, post_id, category_id)

    redirect "/categories/#{category_id}"
  end

  ##
  # POST /threads/:id/posts
  #
  # Skapar ett nytt inlägg i en tråd.
  #
  # @param id [Integer] tråd ID
  # @return [Redirect] redirect till tråden
  #
  post '/threads/:id/posts' do |id|
    redirect '/login' unless logged_in?

    post_id = Post.create(db, params["content"], current_user["id"], id)

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
  # Visar registreringsformuläret.
  #
  # @return [ERB] registreringssidan
  #
  get '/registrera' do
    erb :"users/registrera"
  end

  ##
  # POST /registrera
  #
  # Skapar ett nytt användarkonto.
  #
  # @return [Redirect] redirect till login
  #
  post '/registrera' do
    username = params[:username]
    password = BCrypt::Password.create(params[:password])

    User.create(db, username, password)

    redirect '/login'
  end

  ##
  # GET /login
  #
  # Visar login-formuläret.
  #
  # @return [ERB] login sidan
  #
  get '/login' do
    erb :"users/login"
  end

  #
  # POST /login
  #
  # Loggar in en användare om lösenordet stämmer.
  #
  # @return [Redirect, ERB] redirect vid lyckad inloggning, annars login sidan
  #
  post '/login' do
    user = User.find_by_username(db, params[:username])

    if user.nil?
      @error = "Kontot finns inte"
      return erb :"users/login"
    end

    unless BCrypt::Password.new(user["password_digest"]) == params[:password]
      @error = "Fel lösenord"
      försök -= 1
      if försök == 0
        return erb :'users/förmångaförsök'
      end
      return erb :"users/login"
    end

    session[:user_id] = user["id"]
    redirect '/'
  end

  ##
  # GET /logout
  #
  # Loggar ut användaren.
  #
  # @return [Redirect] redirect till startsidan
  #
  get '/logout' do
    session.clear
    redirect '/'
  end

  ##
  # GET /users/tabort
  #
  # Visar sidan för att ta bort konto.
  #
  # @return [ERB] tabort sidan
  #
  get '/users/tabort' do
    redirect '/login' unless logged_in?
    erb :"users/tabort"
  end

  ##
  # POST /users/:id/tabort
  #
  # Tar bort användarens konto.
  #
  # @param id [Integer] användar ID
  # @return [Redirect] redirect till startsidan
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
  # Uppdaterar användarens lösenord.
  #
  # @param id [Integer] användar ID
  # @return [ERB] tabort sidan med success/error
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
