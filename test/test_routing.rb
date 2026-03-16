# frozen_string_literal: true

require_relative "test_helper"

class TestRouting < Minitest::Test
  include Rack::Test::Methods

  def setup
    @app = Class.new(Serviette::Application)
  end

  def app
    Rack::Lint.new(@app)
  end

  def test_get
    @app.get("/hello") { "hello" }
    get "/hello"
    assert_equal 200, last_response.status
    assert_equal "hello", last_response.body
  end

  def test_post
    @app.post("/submit") { status 201; "created" }
    post "/submit"
    assert_equal 201, last_response.status
    assert_equal "created", last_response.body
  end

  def test_put
    @app.put("/update") { "updated" }
    put "/update"
    assert_equal 200, last_response.status
    assert_equal "updated", last_response.body
  end

  def test_delete
    @app.delete("/remove") { "deleted" }
    delete "/remove"
    assert_equal 200, last_response.status
    assert_equal "deleted", last_response.body
  end

  def test_not_found
    get "/nope"
    assert_equal 404, last_response.status
    assert_equal "Not Found\n", last_response.body
  end

  def test_wrong_verb
    @app.get("/hello") { "hello" }
    post "/hello"
    assert_equal 404, last_response.status
  end

  def test_named_param
    @app.get("/users/:id") { params["id"] }
    get "/users/42"
    assert_equal 200, last_response.status
    assert_equal "42", last_response.body
  end

  def test_multiple_named_params
    @app.get("/users/:user_id/posts/:post_id") do
      "#{params["user_id"]}-#{params["post_id"]}"
    end
    get "/users/7/posts/99"
    assert_equal "7-99", last_response.body
  end

  def test_named_param_block_args
    @app.get("/hello/:name") do |name|
      "Hello, #{name}!"
    end
    get "/hello/world"
    assert_equal "Hello, world!", last_response.body
  end

  def test_static_does_not_match_subpath
    @app.get("/hello") { "hello" }
    get "/hello/world"
    assert_equal 404, last_response.status
  end

  def test_param_does_not_match_extra_segments
    @app.get("/users/:id") { "ok" }
    get "/users/42/edit"
    assert_equal 404, last_response.status
  end

  def test_routes_matched_in_order
    @app.get("/a") { "first" }
    @app.get("/:x") { "second" }

    get "/a"
    assert_equal "first", last_response.body
    get "/b"
    assert_equal "second", last_response.body
  end

  def test_root
    @app.get("/") { "root" }
    get "/"
    assert_equal "root", last_response.body
  end

  def test_same_path_different_verbs
    @app.get("/users")  { "got" }
    @app.post("/users") { status 201; "created" }

    get "/users"
    assert_equal 200, last_response.status
    assert_equal "got", last_response.body

    post "/users"
    assert_equal 201, last_response.status
    assert_equal "created", last_response.body
  end

  def test_static_after_param
    @app.get("/users/:id/edit") { params["id"] }
    get "/users/42/edit"
    assert_equal "42", last_response.body

    get "/users/42"
    assert_equal 404, last_response.status
  end

  def test_param_value_with_dots_and_hyphens
    @app.get("/users/:name") { params["name"] }
    get "/users/john.doe"
    assert_equal "john.doe", last_response.body
    get "/users/my-name"
    assert_equal "my-name", last_response.body
  end

  def test_param_with_literal_suffix
    @app.get("/foo/:bar.html") { params["bar"] }
    get "/foo/hello.html"
    assert_equal "hello", last_response.body

    get "/foo/hello.txt"
    assert_equal 404, last_response.status
  end

  def test_literal_dot_in_path_is_escaped
    @app.get("/api/v1.0/status") { "ok" }
    get "/api/v1.0/status"
    assert_equal "ok", last_response.body

    get "/api/v1X0/status"
    assert_equal 404, last_response.status
  end

  def test_regex_route
    @app.get(%r{\A/items/(\d+)\z}) { |id| id }
    get "/items/123"
    assert_equal "123", last_response.body

    get "/items/abc"
    assert_equal 404, last_response.status
  end

  def test_request_available_in_handler
    @app.get("/info") { request.path_info }
    get "/info"
    assert_equal "/info", last_response.body
  end

  def test_response_set_status_and_headers
    @app.get("/custom") do
      response.status = 201
      response["X-Custom"] = "yes"
      "created"
    end
    get "/custom"
    assert_equal 201, last_response.status
    assert_equal "yes", last_response["X-Custom"]
    assert_equal "created", last_response.body
  end

  def test_request_method
    @app.post("/echo") { request.request_method }
    post "/echo"
    assert_equal "POST", last_response.body
  end

  # Helper methods

  def test_status_helper
    @app.get("/") do
      status 201
      "created"
    end
    get "/"
    assert_equal 201, last_response.status
    assert_equal "created", last_response.body
  end

  def test_status_helper_getter
    @app.get("/") do
      status 201
      [200, {}, [status.to_s]]
    end
    get "/"
    assert_equal "201", last_response.body
  end

  def test_headers_helper
    @app.get("/") do
      headers "x-custom" => "yes", "x-other" => "no"
      "ok"
    end
    get "/"
    assert_equal "yes", last_response["x-custom"]
    assert_equal "no", last_response["x-other"]
  end

  def test_content_type_helper
    @app.get("/") do
      content_type "application/json"
      '{"ok":true}'
    end
    get "/"
    assert_equal "application/json", last_response["content-type"]
  end

  def test_redirect_helper
    @app.get("/old") do
      redirect "/new"
    end
    get "/old"
    assert_equal 302, last_response.status
    assert_equal "/new", last_response["location"]
  end

  def test_redirect_helper_custom_status
    @app.get("/old") do
      redirect "/new", 301
    end
    get "/old"
    assert_equal 301, last_response.status
    assert_equal "/new", last_response["location"]
  end

  def test_not_found_helper
    @app.get("/gone") do
      not_found "nope"
    end
    get "/gone"
    assert_equal 404, last_response.status
    assert_equal "nope", last_response.body
  end
end
