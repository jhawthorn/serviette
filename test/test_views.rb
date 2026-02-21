# frozen_string_literal: true

require_relative "test_helper"
require "tmpdir"
require "fileutils"

class TestViews < Minitest::Test
  def setup
    @views_dir = Dir.mktmpdir
    @app = Class.new(Serviette::Application)
    @app.views = @views_dir
  end

  def teardown
    FileUtils.rm_rf(@views_dir)
  end

  def request(method, path)
    @app.call("REQUEST_METHOD" => method, "PATH_INFO" => path)
  end

  def write_template(name, content)
    File.write(File.join(@views_dir, "#{name}.erb"), content)
  end

  # String return auto-wrapping

  def test_string_return
    @app.get("/hello") { "hello" }
    assert_equal [200, {}, ["hello"]], request("GET", "/hello")
  end

  def test_tuple_return_still_works
    @app.get("/hello") { [201, { "X-Custom" => "yes" }, ["created"]] }
    assert_equal [201, { "X-Custom" => "yes" }, ["created"]], request("GET", "/hello")
  end

  # ERB rendering

  def test_erb_renders_template
    write_template("index", "<h1>Hello</h1>")
    @app.get("/") { erb :index }
    assert_equal [200, {}, ["<h1>Hello</h1>"]], request("GET", "/")
  end

  def test_erb_with_instance_variable
    write_template("hello", "<h1>Hello, <%= @name %>!</h1>")
    @app.get("/hello/:name") do |name|
      @name = name
      erb :hello
    end
    assert_equal [200, {}, ["<h1>Hello, world!</h1>"]], request("GET", "/hello/world")
  end

  def test_erb_with_multiple_instance_variables
    write_template("profile", "<%= @user %> - <%= @role %>")
    @app.get("/profile") do
      @user = "alice"
      @role = "admin"
      erb :profile
    end
    assert_equal [200, {}, ["alice - admin"]], request("GET", "/profile")
  end

  def test_erb_raises_without_views_configured
    app = Class.new(Serviette::Application)
    app.get("/") { erb :index }
    assert_raises(RuntimeError) { app.call("REQUEST_METHOD" => "GET", "PATH_INFO" => "/") }
  end
end
