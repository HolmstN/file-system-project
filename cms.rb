require 'sinatra'
require 'sinatra/reloader'
require 'tilt/erubis'
require 'redcarpet'
require 'yaml'
require 'bcrypt'

def data_path
  if ENV["RACK_ENV"] == "test"
    File.expand_path("../test/data", __FILE__)
  else
    File.expand_path("../data", __FILE__)
  end
end

def credentials_path
  if ENV["RACK_ENV"] == "test"
   File.expand_path("../test/users.yml", __FILE__)
  else
   File.expand_path("../users.yml", __FILE__)
  end
end

configure do
  enable :sessions
  set :session_secret, 'secret'
end

helpers do
  def render_markdown(text)
    markdown = Redcarpet::Markdown.new(Redcarpet::Render::HTML)
    markdown.render text
  end

  def load_file_content(path)
    content = File.read(path)
    case File.extname(path)
    when '.md'
      render_markdown erb render_markdown(content)
    when '.txt'
      headers["Content-Type"] = "text/plain"
      content
    end
  end

  def user_signed_in?
    session.key?(:username)
  end

  def require_signed_in_user
    unless user_signed_in?
      session[:message] = "You must be signed in to do that."
      redirect "/"
    end
  end

  def valid_credentials?(username, password)
    credentials = YAML.load_file(credentials_path)

    if credentials.key?(username)
      bcrypt_password = BCrypt::Password.new(credentials[username])
      bcrypt_password == password
    else
      false
    end
  end
end

get '/' do
  pattern = File.join(data_path, "*")
  @files = Dir.glob(pattern).map do |path|
    File.basename(path)
  end

  erb :index
end

get '/new' do
  require_signed_in_user
  erb :new
end

post "/make-new-doc" do
  require_signed_in_user

  doc_name = params[:doc_name].to_s

  if doc_name.size == 0
    session[:message] = "A name is required."
    status 422
    erb :new
  else
    file_path = File.join(data_path, doc_name)

    File.write(file_path, "")

    session[:message] = "Successfully created #{doc_name}"
    redirect "/"
  end
end

get '/users/login' do

  erb :login
end

post '/users/login' do
  if valid_credentials?(params[:username], params[:password])
    session[:message] = "Welcome!"
    session[:username] = params[:username]

    redirect '/'
  else
    status 422
    session[:message] = "Invalid Credentials"
    erb :login
  end
end

get '/users/signout' do
  session.delete(:username)

  session[:message] = "You have been signed out"

  redirect '/'
end

get "/:file_name" do
  file_path = File.join(data_path, File.basename(params[:file_name]))

  if File.exist?(file_path)
    load_file_content(file_path)
  else
    session[:message] = "#{params[:file_name]} does not exist."
    redirect "/"
  end
end

get "/:file_name/edit" do
  require_signed_in_user

  file_path = File.join(data_path, File.basename(params[:file_name]))

  @content = File.read(file_path)

  erb :edit
end

get "/:file_name/delete" do
  require_signed_in_user

  file_path = File.join(data_path, params[:file_name])

  File.delete(file_path)

  redirect '/'
end


post "/:file_name/saved" do
  require_signed_in_user

  file_path = File.join(data_path, File.basename(params[:file_name]))

  File.write(file_path, params[:content])

  session[:message] = "Successfully saved changes to #{params[:file_name]}"

  redirect "/"
end
