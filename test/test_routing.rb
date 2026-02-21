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
end
