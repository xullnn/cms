require 'sinatra'
require 'sinatra/reloader'
require 'tilt/erubis'
require 'redcarpet'
require 'pry'
require 'fileutils'
require 'yaml'
require 'bcrypt'
# require_relative 'file_version'

VALID_IMAGE_TYPES = ['.png', '.jpg', '.jpeg', '.bmp', '.pdf']
VALID_DOC_TYPES = ['.md', '.txt']

configure do
  enable :sessions
  set :session_secret, 'secret key'
end

get "/" do
  headers["Content-Type"] = "text/html; charset=utf-8"

  @files = Dir.children(data_path)
  erb :index
end

post "/files/create" do
  validate_user
  new_name = params[:name].to_s.strip
  content = params[:content].to_s.strip
  if invalid_file_name?(new_name)
    status 422
    erb :new
  else
    create_new_version(new_name, 1, content)
    session[:message] = "#{new_name} was created."
    redirect "/files/#{new_name}/1"
  end
end

get "/files/:filename/:version" do
  headers["Content-Type"] = "text/html; charset=utf-8"
  file_name = params[:filename]
  version = params[:version]
  file_path = File.join(file_dir(file_name, version), file_name)
  if File.exist?(file_path)
    @content = load_file_content(file_path)
    @versions = extract_version_and_content(file_name).keys.sort!
    erb :view
  else
    session[:message] = "#{params[:filename]} does not exist."
    redirect "/"
  end
end

get "/files/:filename/:version/edit" do
  validate_user
  headers["Content-Type"] = "text/html; charset=utf-8"
  @file_name = params[:filename]
  file_path = File.join(file_dir(@file_name, params[:version]), @file_name)
  @content = File.read(file_path)
  erb :edit
end

post "/files/:filename/clean_up_olds" do
  validate_user
  file_name = params[:filename]
  latest_version = latest_version_of(file_name)
  (1...latest_version.to_i).each do |version|
    dir = file_dir(file_name, version)
    FileUtils.rm_rf(dir)
  end
  FileUtils.mv(file_dir(file_name, latest_version), file_dir(file_name, 1))
  session[:message] = "Versions cleaned up."
  redirect "/files/#{file_name}/1"
end

post "/files/:filename" do
  validate_user
  file_name = params[:filename]
  content = params[:content]
  validate_content_change(content, file_name)
  new_version_number = (latest_version_of(file_name).to_i + 1).to_s
  create_new_version(file_name, new_version_number, content)

  session[:message] = "#{file_name} has been updated."
  redirect "/files/#{file_name}/#{new_version_number}"
end

def validate_content_change(content, file_name)
  old_content = File.read(File.join(data_path, "#{file_name}/#{latest_version_of(file_name)}/#{file_name}"))
  if content == old_content
    session[:message] = "No change was made, new version wasn't created."
    status 422
    redirect back
  end
end

get "/files/new" do
  validate_user
  erb :new
end

post "/:file_name/duplicate" do
  validate_user
  file_name = params[:file_name]
  existed_files = Dir.children(data_path)
  if existed_files.include?(file_name)
    versions_and_contents = extract_version_and_content(file_name)
    new_file_name = file_name.sub(/\./, "_dup.")
    versions_and_contents.each do |version, content|
      create_new_version(new_file_name, version, content)
    end
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
    FileUtils.rm_rf(file_path)
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
  if !VALID_IMAGE_TYPES.include?(file_type)
    session[:message] = "#{file_type} is not a valid file type"
    redirect "/"
  end
  file_path = File.join(image_path, file_name)
  File.open(file_path, 'w+') { |f| f.write(params[:image_file][:tempfile].read) }
  session[:message] = "#{file_name} successfully uploaded, click <a href=\"/images/#{file_name}\" target=\"_blank\">here</a> to view image."
  redirect "/"
end

post "/:filename/keep_latest" do
  validate_user
  file_path = File.join(data_path, params[:filename])
  cmsfile = CMSFile.new.read(File.read(file_path), file_path)
  latest_version_content = cmsfile.latest_content_pair.last
  File.open(file_path, 'w') { |f| f.write(CMSFile.format_input(latest_version_content)) }
  session[:message] = "Udated successfully, only keeping latest version."
  redirect "/#{params[:filename]}"
end

# -------------------------------------------------------------------------------------------------------------------------------------------

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

def load_file_content(file_path)
  filetype = File.extname(file_path)
  content = File.read(file_path)
  if filetype == '.txt'
    content
  elsif filetype == '.md'
    markdown_to_html(content)
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
  valid_types = VALID_DOC_TYPES.join(', ')
  if name.empty?
    session[:message] = "File name cannot be empty."
  elsif !VALID_DOC_TYPES.include?(File.extname(name))
    session[:message] = "#{File.extname(name)} is not a valid type, only accept #{valid_types}"
  else
    false
  end
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

def create_new_version(file_name, version, content)
  dir = file_dir(file_name, version)
  FileUtils.mkdir_p(dir)
  file_path = File.join(dir, file_name)
  File.open(file_path, 'w+') { |f| f.write(content) }
end

def file_dir(file_name, version)
  File.join(data_path, "/#{file_name}/#{version}")
end

def latest_version_of(file_name)
  versions = Dir.children(File.join(data_path, file_name))
  versions.max_by { |v| v.to_i }
end

def extract_version_and_content(file_name)
  versions = Dir.children(File.join(data_path, file_name))
  versions.each_with_object(Hash.new) do |v, hash|
    content = File.read(File.join(data_path, "#{file_name}/#{v}/#{file_name}"))
    hash[v] = content
  end
end
