require 'sinatra'
require 'sinatra/reloader'
require 'tilt/erubis'
require 'redcarpet'
require 'pry'
require 'fileutils'
require 'yaml'
require 'bcrypt'
require_relative 'file_version'

VALID_FILE_TYPES = ['.png', '.jpg', '.jpeg', '.bmp', '.pdf']

configure do
  enable :sessions
  set :session_secret, 'secret key'
end

get "/" do
  headers["Content-Type"] = "text/html; charset=utf-8"

  pattern = File.join(data_path, "*")
  @files = Dir.glob(pattern).map { |path| File.basename(path) }
  erb :index
end

get "/:filename" do
  headers["Content-Type"] = "text/html; charset=utf-8"
  file_path = File.join(data_path, params[:filename])
  @file_name = params[:filename]
  version = params[:version] || 'unspecified'
  if File.exist?(file_path)
    load_file_content(file_path, version)
    erb :display_file
  else
    session[:message] = "#{params[:filename]} does not exist."
    redirect "/"
  end
end

get "/:filename/edit" do
  validate_user
  headers["Content-Type"] = "text/html; charset=utf-8"
  file_path = File.join(data_path, params[:filename])

  @file = params[:filename]
  cmsfile = CMSFile.new.read(File.read(file_path), file_path)
  @content = cmsfile.latest_content_pair.last.strip
  @version_time = cmsfile.latest_content_pair.first
  erb :edit
end

post "/:filename" do
  validate_user
  headers["Content-Type"] = "text/html; charset=utf-8"
  file_path = File.join(data_path, File.basename(params[:filename]))
  @file = params[:filename]
  content = File.read(file_path)
  updated_content = params[:content]
  if updated_content && updated_content != content
    File.open(file_path, 'a') { |f| f.write(CMSFile.format_input(updated_content)) }
  end
  session[:message] = "#{params[:filename]} has been updated."
  redirect "/"
end

get "/files/new" do
  validate_user
  headers["Content-Type"] = "text/html; charset=utf-8"
  erb :new
end

post "/files/create" do
  validate_user
  headers["Content-Type"] = "text/html; charset=utf-8"
  new_name = params[:name].strip
  if invalid_file_name?(new_name)
    session[:message] = "A name is required."
    erb :new
  else
    file_path = data_path + "/" + new_name
    CMSFile.initialize_empty_file(file_path)
    session[:message] = "#{new_name} was created."
    redirect "/"
  end
end

post "/:file_name/duplicate" do
  validate_user
  file_name = params[:file_name]
  existed_files = Dir.children(data_path)
  if existed_files.include?(file_name)
    new_file_name = file_name.sub(/\./, "_dup.")
    old_file_path = File.join(data_path, file_name)
    new_file_path = File.join(data_path, new_file_name)
    File.open(new_file_path, 'w+') { |f| f.write(File.read(old_file_path)) }
    session[:message] = "A duplication of #{file_name}(#{new_file_name}) was created."
  else
    session[:message] = "#{file_name} is not a valid file name"
  end
  redirect "/"
end

post "/:file_name/delete" do
  validate_user
  file_name = params[:file_name]
  existed_files = Dir.children(data_path)
  if existed_files.include?(file_name)
    file_path = File.join(data_path, file_name)
    File.delete(file_path)
    session[:message] = "#{file_name} was deleted"
  else
    session[:message] = "#{file_name} is not a valid file name"
  end
  redirect "/"
end

get "/users/signin" do
  headers["Content-Type"] = "text/html; charset=utf-8"
  erb :signin
end

post "/users/signin" do
  user_name, password = params[:user_name], params[:password]

  if valid_user?(user_name, password)
    session[:signin_as] = user_name
    session[:message] = "Welcome!"
    redirect "/"
  else
    session[:message] = "Invalid Credentials"
    status 422
    erb :signin
  end
end

post '/users/signout' do
  session.delete(:signin_as)
  session[:message] = "You have signed out."
  redirect "/"
end

get "/users/signup" do
  erb :signup
end

post "/users/signup" do
  name, password = params[:user_name], params[:password]
  validate_signup_name_and_password(name, password)
  new_user = YAML.dump ({name => BCrypt::Password.create(password).to_s})
  new_user.gsub!("---\n", '')
  File.open(user_path, 'a') { |f| f.write(new_user) }

  session[:signin_as] = name
  session[:message] = "New account was created, UserName: \"#{name}\""
  redirect "/"
end

post "/images/upload" do
  file_name = params[:image_file][:filename]
  file_type = File.extname(file_name).downcase
  if !VALID_FILE_TYPES.include?(file_type)
    session[:message] = "#{file_type} is not a valid file type"
    redirect "/"
  end
  file_path = File.join(image_path, file_name)
  File.open(file_path, 'w+') { |f| f.write params[:image_file][:tempfile].read }
  session[:message] = "#{file_name} successfully uploaded, click <a href=\"/images/#{file_name}\" target=\"_blank\">here</a> to view image."
  redirect "/"
end

post "/:filename/keep_latest" do
  validate_user
  file_path = File.join(data_path, params[:filename])
  cmsfile = CMSFile.new.read(File.read(file_path), file_path)
  latest_version_content = cmsfile.latest_content_pair.last
  File.open(file_path, 'w') { |f| f.write(CMSFile.format_input(latest_version_content)) }
  session[:message] = "Udated successfully, only left latest version."
  redirect "/#{params[:filename]}"
end

# ----------------------------------------------------------------------

def validate_signup_name_and_password(name, password)
  name_error = check_for_name(name)
  password_error = check_for_password(password)
  if name_error || password_error
    redirect "/users/signup"
  end
end

def check_for_name(name)
  if name.include?(' ') || name.delete(' ').size < 3
    session[:message] = "\"#{name}\" isn't a valid user name."
  elsif load_user_credentials[name]
    session[:message] = "Sorry \"#{name}\" has been taken."
  end
end

def check_for_password(password)
  if password.include?(' ') || password.delete(' ').size < 6
    msg = session[:message] || ''
    session[:message] = [msg, "Invalid password."].join("<br>")
  end
end

def markdown_to_html(content)
  markdown = Redcarpet::Markdown.new(Redcarpet::Render::HTML)
  markdown.render(content)
end

def load_file_content(file_path, version)
  filetype = File.extname(params[:filename])
  content = File.read(file_path)
  @cmsfile = CMSFile.new.read(content, file_path)
  validate_version(version, @cmsfile)
  if filetype == '.md'
    md_contents = @cmsfile.contents.map { |t, text| [t, markdown_to_html(text)] }.to_h
    @cmsfile.contents = md_contents
  end
  @version = version
  @cmsfile
end

def validate_version(version, cmsfile)
  timestamps = cmsfile.contents.keys
  unless timestamps.include?(version) || ['unspecified', 'all'].include?(version)
    session[:message] = "Version #{version} does not exist."
    redirect "/"
  end
end

def data_path
  if ENV["RACK_ENV"] == 'test'
    File.expand_path("../test/data", __FILE__)
  else
    File.expand_path("../data", __FILE__)
  end
end

def user_path
  if ENV['RACK_ENV'] == 'test'
    File.expand_path("../test/users.yaml", __FILE__)
  else
    File.expand_path("../config/users.yaml", __FILE__)
  end
end

def image_path
  if ENV['RACK_ENV'] == 'test'
    File.expand_path("../test/images", __FILE__)
  else
    File.expand_path("../public/images", __FILE__)
  end
end

def load_user_credentials
  YAML.load_file(user_path)
end

def invalid_file_name?(name)
  name.empty? || File.extname(name).empty?
end

def user_signed_in?
  session[:signin_as] && !session[:signin_as].empty?
end

def validate_user
  unless user_signed_in?
    session[:message] = "You don't have permission for this"
    redirect "/"
  end
end

def valid_user?(user_name, password)
  users = load_user_credentials
  if users.key?(user_name)
    bcrypt_password = BCrypt::Password.new(users[user_name])
    bcrypt_password == password
  else
    false
  end
end

def session
  last_request.env["rack.session"]
end

helpers do
  def signin_signout_signup_button
    if !user_signed_in?
      "
      <form action=\"/users/signin\" method=\"get\">
        <button type=\"submit\">Sign in</button>
      </form>
      <form action=\"/users/signup\" method=\"get\">
        <button type=\"submit\">Signup a new account</button>
      </form>
      "
    else
       "<p>Signed in as #{session[:signin_as]}</p>
       <form action=\"/users/signout\" method=\"post\">
        <button type=\"submit\">Sign out</button>
      </form>"
    end
  end

  def upload_image_button
    if user_signed_in?
      "<label>Upload Image: </label>
      <form action=\"/images/upload\"
             method=\"post\"
             id=\"form_upload_image\"
             enctype=\"multipart/form-data\"
             accept=\"image/png, image/jpeg, image/bmp, image/jpg, image/pdf\">
        <input id=\"btn_upload_image\" name=\"image_file\" type=\"file\">
        <button type=\"submit\">Submit</button>
      </form>"
    end
  end
end
