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
end
