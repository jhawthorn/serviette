# frozen_string_literal: true

require_relative "test_helper"

class TestRactor < Minitest::Test
  def build_app
    app = Class.new(Serviette::Application)
    app.get("/")             { [200, {}, ["root"]] }
    app.get("/hello/:name")  { [200, {}, [params["name"]]] }
    app.get("/users/:id/posts/:post_id") do
      [200, {}, ["#{params["id"]}-#{params["post_id"]}"]]
    end
    app.freeze
    app
  end

  # Builds a full Rack env with Rack::MockRequest (which itself can only run
  # on the main Ractor) and calls the app with it inside a Ractor.
  def call_in_ractor(app, path, **opts)
    env = Rack::MockRequest.env_for(path, opts)
    input = env.delete("rack.input")&.read.to_s
    env.delete("rack.errors")
    Ractor.new(app, env, input) do |a, e, i|
      e["rack.input"] = StringIO.new(i)
      e["rack.errors"] = StringIO.new
      s, h, b = a.call(e)
      [s, h, b.to_enum(:each).to_a]
    end.value
  end

  def test_basic_request_in_ractor
    app = build_app
    result = Ractor.new(app) do |a|
      a.call("REQUEST_METHOD" => "GET", "PATH_INFO" => "/")
    end.value

    assert_equal [200, {}, ["root"]], result
  end

  def test_named_params_in_ractor
    app = build_app
    result = Ractor.new(app) do |a|
      a.call("REQUEST_METHOD" => "GET", "PATH_INFO" => "/hello/world")
    end.value

    assert_equal [200, {}, ["world"]], result
  end

  def test_parallel_ractors
    app = build_app
    paths = ["/", "/hello/alice", "/hello/bob", "/users/1/posts/99"]

    results = paths.map do |path|
      Ractor.new(app, path) do |a, p|
        a.call("REQUEST_METHOD" => "GET", "PATH_INFO" => p)
      end
    end.map(&:value)

    assert_equal [200, {}, ["root"]],  results[0]
    assert_equal [200, {}, ["alice"]], results[1]
    assert_equal [200, {}, ["bob"]],   results[2]
    assert_equal [200, {}, ["1-99"]],  results[3]
  end

  def test_not_found_in_ractor
    app = build_app
    status, = Ractor.new(app) do |a|
      a.call("REQUEST_METHOD" => "GET", "PATH_INFO" => "/nope")
    end.value

    assert_equal 404, status
  end

  def test_not_found_handler_in_ractor
    app = Class.new(Serviette::Application)
    app.not_found { "custom" }
    app.freeze
    status, _, body = Ractor.new(app) do |a|
      a.call("REQUEST_METHOD" => "GET", "PATH_INFO" => "/nope")
    end.value

    assert_equal 404, status
    assert_equal ["custom"], body
  end

  def test_request_and_response_in_ractor
    app = Class.new(Serviette::Application)
    app.get("/info") do
      response.status = 201
      response["X-Custom"] = "yes"
      request.path_info
    end
    app.freeze

    status, headers, body = Ractor.new(app) do |a|
      a.call("REQUEST_METHOD" => "GET", "PATH_INFO" => "/info")
    end.value

    assert_equal 201, status
    assert_equal "yes", headers["X-Custom"]
    assert_equal ["/info"], body
  end

  def test_streaming_body_in_ractor
    app = Class.new(Serviette::Application)
    app.get("/stream/:name") do
      proc { |stream| stream.write "hello #{params["name"]}" }
    end
    app.freeze

    # The body is consumed where a server would consume it: inside the Ractor.
    status, written = Ractor.new(app) do |a|
      response = a.call("REQUEST_METHOD" => "GET", "PATH_INFO" => "/stream/ractor")
      out = StringIO.new
      response[2].call(out)
      [response[0], out.string]
    end.value

    assert_equal 200, status
    assert_equal "hello ractor", written
  end

  def test_rack_request_helpers_in_ractor
    app = Class.new(Serviette::Application)
    app.post("/form") do
      status 201
      content_type "text/plain"
      [request.ip, request.scheme, request.params["a"], request.params["b"]].join(" ")
    end
    app.freeze

    status, headers, body = call_in_ractor(app, "/form?a=1",
      method: "POST", input: "b=2", "REMOTE_ADDR" => "127.0.0.1",
      "HTTP_X_FORWARDED_FOR" => "1.2.3.4", "HTTP_X_FORWARDED_PROTO" => "https")

    assert_equal 201, status
    assert_equal "text/plain", headers["content-type"]
    assert_equal ["1.2.3.4 https 1 2"], body
  end

  def test_rack_static_in_ractor
    app = Rack::Builder.new do
      use Rack::Static, urls: ["/test_ractor.rb"], root: __dir__
      run Ractor.shareable_lambda { |_env| [404, {}, []] }
    end
    app.freeze_app
    app = Ractor.make_shareable(app.to_app)

    status, headers, body = call_in_ractor(app, "/test_ractor.rb")

    assert_equal 200, status
    assert_equal "text/x-script.ruby", headers["content-type"]
    assert_equal File.read(__FILE__), body.join
  end
end
