ENV["RACK_ENV"] = "test"

require "minitest/autorun"
require "rack/test"
require 'fileutils'

require_relative "../cms"

class AppTest < Minitest::Test
  include Rack::Test::Methods

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
    File.open(File.join(data_path, name), "w") do |file|
      file.write(content)
    end
  end

  def admin_session
    { "rack.session" => { username: "admin" } }
  end

  def session
    last_request.env["rack.session"]
  end

  def admin_session
     { "rack.session" => { username: "admin" } }
  end

  def test_index_signed_out
    create_document "about.md"

    get '/'

    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_includes last_response.body, "<form action='/users/login'"
    assert_includes last_response.body, "Sign In"
  end

  def test_index_signed_in
    create_document "about.md"
    create_document "changes.txt"

    get "/", {}, admin_session

    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_includes last_response.body, "about.md"
    assert_includes last_response.body, "changes.txt"
  end

  def test_viewing_text_document
    create_document "history.txt", "Ruby 2.3 released"

    get "/history.txt"

    assert_equal 200, last_response.status
    assert_equal "text/plain", last_response["Content-Type"]
    assert_includes last_response.body, "Ruby 2.3 released"
  end

  def test_view_document_not_exist
    get '/falala.txt'

    assert_equal 302, last_response.status
    assert_equal "falala.txt does not exist.", session[:message]
  end

  def test_updating_document
    post "/changes.txt/saved", {content: "new content"}, admin_session

    assert_equal 302, last_response.status
    assert_equal "Successfully saved changes to changes.txt", session[:message]

    get "/changes.txt"
    assert_equal 200, last_response.status
    assert_includes last_response.body, "new content"
  end

  def test_markdown_document
    create_document "new.md", "`This is markdown code`"

    get '/new.md'

    assert_equal 200, last_response.status
    assert_includes last_response.body, "This is markdown code"
    !assert_includes last_response.body, "<code>"
  end

  def test_editing_document
    create_document "changes.txt"

    get "/changes.txt/edit", {}, admin_session

    assert_equal 200, last_response.status
    assert_includes last_response.body, "<textarea"
    assert_includes last_response.body, %q(<button type='submit')
  end

  def test_signin_form
    get "/users/login"

    assert_equal 200, last_response.status
    assert_includes last_response.body, "<input"
    assert_includes last_response.body, %q(<button type='submit')
  end

  def test_signin
    post "/users/login", username: "admin", password: "secret"
    assert_equal 302, last_response.status

    get last_response["Location"]
    assert_includes last_response.body, "Welcome"
    assert_includes last_response.body, "Signed in as admin"
  end

  def test_signin_with_bad_credentials
    post "/users/login", username: "guest", password: "shhhh"
    assert_equal 422, last_response.status
    assert_includes last_response.body, "Invalid Credentials"
  end

  def test_signout
    post "/users/login", username: "admin", password: "secret"
    get last_response["Location"]
    assert_includes last_response.body, "Welcome"

    get "/users/signout"
    get last_response["Location"]

    assert_includes last_response.body, "You have been signed out"
    assert_includes last_response.body, "Sign In"
  end

  def test_signed_out_edit
    create_document "test.txt"

    get "/test.txt/edit"

    assert_equal 302, last_response.status
    assert_equal "You must be signed in to do that.", session[:message]
  end

  def test_signed_out_saved
    create_document "test.txt"

    post "/test.txt/saved"

    assert_equal 302, last_response.status
    assert_equal "You must be signed in to do that.", session[:message]
  end

  def test_signed_out_new
    get "/new"

    assert_equal 302, last_response.status
    assert_equal "You must be signed in to do that.", session[:message]
  end

  def test_signed_out_post_new
    post "/make-new-doc"

    assert_equal 302, last_response.status
    assert_equal "You must be signed in to do that.", session[:message]
  end

  def test_signed_out_delete
    create_document "test.txt"

    get "/test.txt/delete"

    assert_equal 302, last_response.status
    assert_equal "You must be signed in to do that.", session[:message]
  end
end
