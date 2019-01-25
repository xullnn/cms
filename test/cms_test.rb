ENV["RACK_ENV"] = 'test'

require 'minitest/autorun'
require 'rack/test'

require_relative "../cms"

class TestApp < Minitest::Test
  include Rack::Test::Methods

  ROOT = File.expand_path("../../", __FILE__)

  def app
    Sinatra::Application
  end

  def setup
    FileUtils.mkdir_p(data_path)
  end

  def teardown
    FileUtils.rm_rf(data_path)
  end

  def create_document(name, content = "")
    new_dir = File.join(data_path, "#{name}/1/")
    FileUtils.mkdir_p(new_dir)

    File.open(File.join(new_dir, name), 'w') do |file|
      file.write(content)
    end
  end

  def admin_session
    {"rack.session" => { signin_as: 'admin' }}
  end

  def action_denied
    assert_equal 302, last_response.status
    assert_equal "You don't have permission for this", session[:message]
  end

  def test_index
    create_document('about.md')
    create_document('change.txt')
    create_document('history.txt')

    get "/"
    assert_equal 200, last_response.status
    assert_equal "text/html; charset=utf-8", last_response["Content-Type"]
    filenames = ["about.md", "history.txt", "change.txt"]
    filenames.each do |filename|
      assert_includes last_response.body, filename
    end
  end

  def test_redirection_for_invalid_file_request
    wrong_file_name = "non-existent.txt"
    get "/files/#{wrong_file_name}/1"
    assert_equal 302, last_response.status
    assert_equal "non-existent.txt does not exist.", session[:message]
  end

  def test_markdown_rendering
    create_document("about.md", "## Testing markdown format")
    get "/files/about.md/1"
    assert_equal 200, last_response.status
    assert_equal "text/html; charset=utf-8", last_response["Content-Type"]
    assert_includes last_response.body, "<h2>Testing markdown format</h2>"
  end

  def test_edit_file
    create_document("change.txt", "original_content")

    get "/files/change.txt/1/edit"
    action_denied

    get "/files/change.txt/1/edit", {}, admin_session

    assert_equal 200, last_response.status
    assert_includes last_response.body, "original_content"
  end

  def test_update_file
    create_document("change.txt", "original_content")

    post "/files/change.txt", content: "new content addedxx"
    action_denied

    post "/files/change.txt", {content: "original_content"}, admin_session
    assert_equal 302, last_response.status
    assert_equal "No change was made, new version wasn't created.", session[:message]

    post "/files/change.txt", {content: "new content added"}, admin_session
    assert_equal 302, last_response.status
    assert_equal "change.txt has been updated.", session[:message]
  end

  def test_new_file_page
    get "/files/new"
    action_denied

    get "/files/new", {}, admin_session
    assert_includes last_response.body, "Create new document"
  end

  def test_successful_creation_of_file
    post "/files/create", name: "new_file.txt", content: "test new feature(dir based version control)"
    action_denied

    post "/files/create", { name: "new_file.txt", content: "test new feature(dir based version control)" }, admin_session
    assert_equal 302, last_response.status

    file = File.join(data_path, "/new_file.txt/1/new_file.txt")
    assert_includes File.read(file), "test new feature(dir based version control)"
    assert_equal "new_file.txt was created.", session[:message]
  end

  def test_file_creation_validation
    first_files_count = Dir.children(data_path).size

    post "/files/create", {name: "   "}, admin_session
    assert_equal 422, last_response.status
    assert_includes last_response.body, "File name cannot be empty."

    second_files_count = Dir.children(data_path).size
    assert_equal first_files_count, second_files_count
  end

  def test_existence_of_delete_button
    create_document('about.md')
    create_document('change.txt')
    create_document('history.txt')

    get "/"
    assert_equal 200, last_response.status
    assert_includes last_response.body, "Delete</button>"
  end

  def test_delete_file_successfully
    create_document('about.md')
    create_document('change.txt')
    create_document('history.txt')

    post "/history.txt/delete"
    action_denied

    post "/history.txt/delete", {}, admin_session
    assert_equal 302, last_response.status

    assert_equal "history.txt was deleted", session[:message]
    refute_includes Dir.children(data_path), "history.txt"
  end

  def test_invalid_deletion
    create_document('about.md')
    create_document('change.txt')
    create_document('history.txt')

    post "/history/delete", {}, admin_session
    assert_equal 302, last_response.status

    assert_equal "history is not a valid file name", session[:message]
    assert_includes Dir.children(data_path), "history.txt"
  end

  def test_sign_in_button_at_index_page
    get "/"
    assert_equal 200, last_response.status
    assert_includes last_response.body, "Sign in</button>"
    assert_includes last_response.body, "action=\"/users/signin\""
    assert_includes last_response.body, "method=\"get\""
  end

  def test_form_at_sign_in_page
    get "/users/signin"
    assert_equal 200, last_response.status
    assert_includes last_response.body, "action=\"/users/signin\""
    assert_includes last_response.body, "method=\"post\""
    assert_includes last_response.body, "Sign In</button>"
  end

  def test_hard_coded_sign_in
    post "/users/signin", user_name: "user1", password: "123456"
    assert_equal 302, last_response.status

    assert_equal "Welcome!", session[:message]
    assert_equal "user1", session[:signin_as]

    get last_response["Location"]
    assert_includes last_response.body, "Signed in as user1"
  end

  def test_invalid_user_signin
    post "/users/signin", user_name: "nonadmin", password: "secret"
    assert_equal 422, last_response.status

    assert_nil session[:signin_as]
    assert_includes last_response.body, "Invalid Credentials"
    assert_includes last_response.body, "nonadmin"
  end

  def test_user_sign_out
    get "/", {}, admin_session
    assert_includes last_response.body, "Signed in as admin"

    post "/users/signout"
    assert_equal "You have signed out.", session[:message]

    get last_response["Location"]
    assert_nil session[:signin_as]
    assert_includes last_response.body, "Sign in</button>"
  end

  def test_duplicate_file
    create_document('history.txt')

    post "/history.txt/duplicate"
    action_denied

    post "/history.txt/duplicate", {}, admin_session
    assert_equal "A duplication of history.txt(history_dup.txt) was created.", session[:message]

    post "/abc.txt/duplicate", {}, admin_session
    assert_equal "abc.txt is not a valid file name", session[:message]
  end

# sigup procedure

  def test_signup_button
    get "/"
    assert_includes last_response.body, "Signup a new account"

    get "/", {}, admin_session
    refute_includes last_response.body, "Signup a new account"
  end

  def test_sign_up_page
    get "/users/signup"
    assert_equal 200, last_response.status
    assert_includes last_response.body, "Sign Up</button>"
    assert_includes last_response.body, "password should be equal to or longer than 6 characters and should not include space character"
    assert_includes last_response.body, "user name should be longer than 3 characters."
  end

  def test_signup_with_invalid_name_or_password
    post "/users/signup", user_name: 'Dav d', password: '123456'
    assert_equal 302, last_response.status
    assert_includes session[:message], "\"Dav d\" isn't a valid user name."

    post "/users/signup", user_name: 'David', password: '12346'
    assert_equal 302, last_response.status
    assert_includes session[:message], "Invalid password."

    post "/users/signup", user_name: 'Da', password: '1234'
    assert_equal 302, last_response.status
    assert_includes session[:message], "\"Da\" isn't a valid user name."
    assert_includes session[:message], "Invalid password."
  end

  def test_signup_with_existed_username
    selected_name = load_user_credentials.keys.sample
    post "/users/signup", user_name: "#{selected_name}", password: '123456'
    assert_equal 302, last_response.status
    assert_includes session[:message], "Sorry \"#{selected_name}\" has been taken."
  end

  def test_signup_user_successfully
    count_users = load_user_credentials.size
    post "/users/signup", user_name: "David", password: '123456'
    assert_equal 302, last_response.status
    assert_equal "New account was created, UserName: \"David\"", session[:message]
    assert_includes load_user_credentials.keys, "David"
    assert_equal count_users + 1, load_user_credentials.size
    users = load_user_credentials
    users.delete("David")
    File.open(user_path, 'w') { |f| f.write(YAML.dump(users))}
  end

  def test_upload_file_button
    get "/"
    refute_includes last_response.body, "Upload Image"

    get "/", {}, admin_session
    assert_includes last_response.body, "Upload Image"
  end

  def test_image_type_validation
    type = '.' + ('a'..'f').to_a.shuffle.take(3).join
    parameters = { "image_file" => {
      "filename" => "picture#{type}"
      } }
    post "/images/upload", parameters, admin_session
    assert_equal 302, last_response.status
    assert_equal "#{type} is not a valid file type", session[:message]
  end

  def test_image_uploaded_successfully
    path = File.join(image_path, 'sample.png')
    post "/images/upload", {"image_file" => Rack::Test::UploadedFile.new(path, "image/png")}, admin_session
    assert_includes Dir.children(image_path), "sample.png"
  end

  def test_version_control_for_files
    create_document 'sample.txt', "test version control"

    post "/files/sample.txt", {content: "new content"}, admin_session
    get last_response["Location"]

    assert_equal 2, Dir.children(File.join(data_path, 'sample.txt')).size
  end

  def test_create_invalid_doc_type
    post "/files/create", { name: 'abc.png' }, admin_session
    assert_equal 422, last_response.status
    assert_includes last_response.body, ".png is not a valid type, only accept .md, .txt"
  end

  def test_existence_of_version_list_on_view_page
    create_document 'sample.txt', "test version control"
    5.times { |n| post "/files/sample.txt", {content: "new content #{n}"}, admin_session }

    get last_response["Location"]
    assert_includes last_response.body, "<a href=\"/files/sample.txt/3\">"
    assert_includes last_response.body, "<a href=\"/files/sample.txt/6\">"
  end

  def test_clean_up_old_version
    create_document 'sample.txt', "test version control"
    post "/files/sample.txt/clean_up_olds"
    action_denied

    5.times { |n| post "/files/sample.txt", {content: "new content #{n}"}, admin_session }

    post "/files/sample.txt/clean_up_olds", {}, admin_session
    assert_equal ["1"], Dir.children(File.join(data_path, 'sample.txt'))
  end
end
