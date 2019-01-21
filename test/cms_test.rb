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
    File.open(File.join(data_path, name), 'w') do |file|
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

  def test_history_page
    create_document('history.txt', "2003 - Ruby 1.8 released.")

    get "/history.txt"
    assert_equal 200, last_response.status
    assert_equal "text/html; charset=utf-8", last_response["Content-Type"]
    file_path = File.join(data_path, "history.txt")
    body_contents = last_response.body.split("\n\n").map(&:strip)
    assert_includes last_response.body, "2003 - Ruby 1.8 released."
  end

  def test_redirection_for_invalid_file_request
    wrong_file_name = "non-existent.txt"
    get "/#{wrong_file_name}"
    assert_equal 302, last_response.status
    assert_equal "non-existent.txt does not exist.", session[:message]
  end

  def test_markdown_rendering
    create_document("about.md", "## Testing markdown format")
    get "/about.md"
    assert_equal 200, last_response.status
    assert_equal "text/html; charset=utf-8", last_response["Content-Type"]
    assert_includes last_response.body, "<h2>Testing markdown format</h2>"
  end

  def test_edit_file
    create_document("change.txt", "original_content")

    get "/change.txt/edit"
    action_denied

    get "/change.txt/edit", {}, admin_session

    assert_equal 200, last_response.status
    assert_includes last_response.body, "original_content"
  end

  def test_update_file
    create_document("change.txt", "original_content")

    post "/change.txt", content: "new content addedxx"
    action_denied

    get "/change.txt/edit", {}, admin_session
    post "/change.txt", content: "new content addedxx"
    assert_equal 302, last_response.status
    assert_equal "change.txt has been updated.", session[:message]

    get "/change.txt"
    assert_equal 200, last_response.status
    assert_includes  last_response.body, "new content added"
  end

  def test_new_file_page
    get "/files/new"
    action_denied

    get "/files/new", {}, admin_session
    assert_includes last_response.body, "Add a new document"
  end

  def test_successful_creation_of_file
    post "/files/create", name: "new_file.txt"
    action_denied

    post "/files/create", { name: "new_file.txt" }, admin_session
    assert_equal 302, last_response.status

    assert_equal "new_file.txt was created.", session[:message]
  end

  def test_file_creation_validation
    first_files_count = Dir.children(data_path).size

    post "/files/create", {name: "   "}, admin_session
    assert_equal 302, last_response.status

    assert_equal "A name is required.", session[:message]

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
    get "/", {}, {"rack.session" => { signin_as: "admin" }}
    assert_includes last_response.body, "Signed in as admin"

    post "/users/signout"
    assert_equal "You have been signed out.", session[:message]

    get last_response["Location"]
    assert_nil session[:signin_as]
    assert_includes last_response.body, "Sign in</button>"
  end

  def test_duplicate_file
    create_document('history.txt')

    post "/history.txt/duplicate"
    action_denied

    post "/history.txt/duplicate", {}, {"rack.session" => { signin_as: "admin" }}
    assert_equal "A duplication of history.txt(history_dup.txt) was created.", session[:message]

    post "/abc.txt/duplicate", {}, {"rack.session" => { signin_as: "admin" }}
    assert_equal "abc.txt is not a valid file name", session[:message]
  end

# sigup procedure

  def test_signup_button
    get "/"
    assert_includes last_response.body, "Signup a new account"

    get "/", {}, {"rack.session" => { signin_as: "admin" }}
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

  # there is a upload file button in index page
    # - it is only visible to logged in user
  # signed in user can choose a image file and submit
    # - types of file should be limited(provide a white list)
    # validation
      # first sniffing file type
      # then allow to upload
  # server side will receive this file by params[:image_file]
  # write this file into /images folder
  # redirect to /images/:id page which can view the image just uploaded
  def test_upload_file_button
    get "/"
    refute_includes last_response.body, "Upload Image"

    get "/", {}, {"rack.session" => { signin_as: "admin" }}
    assert_includes last_response.body, "Upload Image"
  end

  def test_image_type_validation
    type = '.' + ('a'..'f').to_a.shuffle.take(3).join
    parameters = { "image_file" => {
      "filename" => "picture#{type}"
      } }
    post "/images/upload", parameters, {"rack.session" => { signin_as: "admin" }}
    assert_equal 302, last_response.status
    assert_equal "#{type} is not a valid file type", session[:message]
  end

  # def test_image_uploaded_successfully
  #   temp_file = Tempfile.new('sample.png')
  #   parameters = { "image_file" => {
  #     "filename" => "sample.png",
  #     "tempfile" => Tempfile.new('sample.png')
  #     } }
  #   post "/images/upload", parameters, {"rack.session" => { signin_as: "admin" }}
  #   assert_includes Dir.children(image_path), "sample.png"
  # end

  def test_version_control_for_files
    # when post "/:filename" happens
      # if content changed, create a new version
      # if no changes keep same
      # both scenario should label a new last update time

      # instead of reading content directly from a file
      # v0(current version) last updated xxx
      # "current content here ......"
        # other versions
          # v1 (last updated at: 2019-01-01)
          # v2 (last updated at: 2018-12-01)
          # v3 (last updated at: 2018-01-01)
        # click on any version can rerender the content in this page
  end

end
