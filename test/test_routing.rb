# frozen_string_literal: true

require_relative "test_helper"

class TestRouting < Minitest::Test
  def setup
    @app = Class.new(Serviette::Application)
  end

  def request(method, path)
    @app.call("REQUEST_METHOD" => method, "PATH_INFO" => path)
  end

  def test_get
    @app.get("/hello") { [200, {}, ["hello"]] }
    assert_equal [200, {}, ["hello"]], request("GET", "/hello")
  end

  def test_post
    @app.post("/submit") { [201, {}, ["created"]] }
    assert_equal [201, {}, ["created"]], request("POST", "/submit")
  end

  def test_put
    @app.put("/update") { [200, {}, ["updated"]] }
    assert_equal [200, {}, ["updated"]], request("PUT", "/update")
  end

  def test_delete
    @app.delete("/remove") { [200, {}, ["deleted"]] }
    assert_equal [200, {}, ["deleted"]], request("DELETE", "/remove")
  end

  def test_not_found
    status, _, body = request("GET", "/nope")
    assert_equal 404, status
    assert_equal ["Not Found\n"], body
  end

  def test_wrong_verb
    @app.get("/hello") { [200, {}, ["hello"]] }
    status, = request("POST", "/hello")
    assert_equal 404, status
  end

  def test_named_param
    @app.get("/users/:id") { [200, {}, [params["id"]]] }
    assert_equal [200, {}, ["42"]], request("GET", "/users/42")
  end

  def test_multiple_named_params
    @app.get("/users/:user_id/posts/:post_id") do
      [200, {}, ["#{params["user_id"]}-#{params["post_id"]}"]]
    end
    assert_equal [200, {}, ["7-99"]], request("GET", "/users/7/posts/99")
  end

  def test_named_param_block_args
    @app.get("/hello/:name") do |name|
      [200, {}, ["Hello, #{name}!"]]
    end
    assert_equal [200, {}, ["Hello, world!"]], request("GET", "/hello/world")
  end

  def test_static_does_not_match_subpath
    @app.get("/hello") { [200, {}, ["hello"]] }
    status, = request("GET", "/hello/world")
    assert_equal 404, status
  end

  def test_param_does_not_match_extra_segments
    @app.get("/users/:id") { [200, {}, ["ok"]] }
    status, = request("GET", "/users/42/edit")
    assert_equal 404, status
  end

  def test_routes_matched_in_order
    @app.get("/a") { [200, {}, ["first"]] }
    @app.get("/:x") { [200, {}, ["second"]] }

    assert_equal [200, {}, ["first"]], request("GET", "/a")
    assert_equal [200, {}, ["second"]], request("GET", "/b")
  end

  def test_root
    @app.get("/") { [200, {}, ["root"]] }
    assert_equal [200, {}, ["root"]], request("GET", "/")
  end

  def test_same_path_different_verbs
    @app.get("/users")  { [200, {}, ["got"]] }
    @app.post("/users") { [201, {}, ["created"]] }

    assert_equal [200, {}, ["got"]], request("GET", "/users")
    assert_equal [201, {}, ["created"]], request("POST", "/users")
  end

  def test_static_after_param
    @app.get("/users/:id/edit") { [200, {}, [params["id"]]] }
    assert_equal [200, {}, ["42"]], request("GET", "/users/42/edit")

    status, = request("GET", "/users/42")
    assert_equal 404, status
  end

  def test_param_value_with_dots_and_hyphens
    @app.get("/users/:name") { [200, {}, [params["name"]]] }
    assert_equal [200, {}, ["john.doe"]], request("GET", "/users/john.doe")
    assert_equal [200, {}, ["my-name"]], request("GET", "/users/my-name")
  end

  def test_param_with_literal_suffix
    @app.get("/foo/:bar.html") { [200, {}, [params["bar"]]] }
    assert_equal [200, {}, ["hello"]], request("GET", "/foo/hello.html")

    status, = request("GET", "/foo/hello.txt")
    assert_equal 404, status
  end

  def test_literal_dot_in_path_is_escaped
    @app.get("/api/v1.0/status") { [200, {}, ["ok"]] }
    assert_equal [200, {}, ["ok"]], request("GET", "/api/v1.0/status")

    status, = request("GET", "/api/v1X0/status")
    assert_equal 404, status
  end

  def test_regex_route
    @app.get(%r{\A/items/(\d+)\z}) { |id| [200, {}, [id]] }
    assert_equal [200, {}, ["123"]], request("GET", "/items/123")

    status, = request("GET", "/items/abc")
    assert_equal 404, status
  end

  def test_request_available_in_handler
    @app.get("/info") { [200, {}, [request.path_info]] }
    assert_equal [200, {}, ["/info"]], request("GET", "/info")
  end

  def test_response_set_status_and_headers
    @app.get("/custom") do
      response.status = 201
      response["X-Custom"] = "yes"
      "created"
    end
    status, headers, body = request("GET", "/custom")
    assert_equal 201, status
    assert_equal "yes", headers["X-Custom"]
    assert_equal ["created"], body
  end

  def test_request_method
    @app.post("/echo") { [200, {}, [request.request_method]] }
    assert_equal [200, {}, ["POST"]], request("POST", "/echo")
  end

  # Helper methods

  def test_status_helper
    @app.get("/") do
      status 201
      "created"
    end
    status, _, body = request("GET", "/")
    assert_equal 201, status
    assert_equal ["created"], body
  end

  def test_status_helper_getter
    @app.get("/") do
      status 201
      [200, {}, [status.to_s]]
    end
    _, _, body = request("GET", "/")
    assert_equal ["201"], body
  end

  def test_headers_helper
    @app.get("/") do
      headers "x-custom" => "yes", "x-other" => "no"
      "ok"
    end
    _, headers, _ = request("GET", "/")
    assert_equal "yes", headers["x-custom"]
    assert_equal "no", headers["x-other"]
  end

  def test_content_type_helper
    @app.get("/") do
      content_type "application/json"
      '{"ok":true}'
    end
    _, headers, _ = request("GET", "/")
    assert_equal "application/json", headers["content-type"]
  end

  def test_redirect_helper
    @app.get("/old") do
      redirect "/new"
    end
    status, headers, _ = request("GET", "/old")
    assert_equal 302, status
    assert_equal "/new", headers["location"]
  end

  def test_redirect_helper_custom_status
    @app.get("/old") do
      redirect "/new", 301
    end
    status, headers, _ = request("GET", "/old")
    assert_equal 301, status
    assert_equal "/new", headers["location"]
  end

  def test_not_found_helper
    @app.get("/gone") do
      not_found "nope"
    end
    status, _, body = request("GET", "/gone")
    assert_equal 404, status
    assert_equal ["nope"], body
  end
end
