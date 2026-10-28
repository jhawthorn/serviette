# frozen_string_literal: true

require_relative "test_helper"
require "tmpdir"
require "fileutils"

class TestViews < Minitest::Test
  def setup
    @views_dir = Dir.mktmpdir
  end

  def teardown
    FileUtils.rm_rf(@views_dir)
  end

  def new_app
    @app = Class.new(Serviette::Application)
    @app.views = @views_dir
    @app
  end

  def request(method, path)
    @app.call("REQUEST_METHOD" => method, "PATH_INFO" => path)
  end

  def write_template(name, content)
    path = File.join(@views_dir, "#{name}.erb")
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, content)
  end

  def html_response(*body)
    [200, {"content-type" => "text/html; charset=utf-8"}, body]
  end

  # String return auto-wrapping

  def test_string_return
    new_app.get("/hello") { "hello" }
    assert_equal [200, {}, ["hello"]], request("GET", "/hello")
  end

  def test_integer_return_sets_status_with_empty_body
    new_app.get("/gone") { 404 }
    assert_equal [404, {}, []], request("GET", "/gone")
  end

  def test_tuple_return_still_works
    new_app.get("/hello") { [201, { "X-Custom" => "yes" }, ["created"]] }
    assert_equal [201, { "x-custom" => "yes" }, ["created"]], request("GET", "/hello")
  end

  def test_status_and_headers_tuple
    new_app.get("/gone") { [410, { "X-Custom" => "yes" }] }
    assert_equal [410, { "x-custom" => "yes" }, []], request("GET", "/gone")
  end

  def test_status_and_body_tuple
    new_app.get("/hello") { [201, ["created"]] }
    assert_equal [201, {}, ["created"]], request("GET", "/hello")
  end

  def test_frozen_tuple_is_not_mutated
    tuple = Ractor.make_shareable([201, { "X-Custom" => "yes" }, ["created"]])
    new_app.get("/hello") { tuple }
    expected = [201, { "x-custom" => "yes" }, ["created"]]
    assert_equal expected, request("GET", "/hello")
    assert_equal expected, request("GET", "/hello")
    assert_equal 3, tuple.size
  end

  def test_oversized_tuple_raises
    new_app.get("/hello") { [200, {}, ["a"], "extra"] }
    assert_raises(ArgumentError) { request("GET", "/hello") }
  end

  # ERB rendering

  def test_erb_renders_template
    write_template("index", "<h1>Hello</h1>")
    new_app.get("/") { erb :index }
    assert_equal html_response("<h1>Hello</h1>"), request("GET", "/")
  end

  def test_erb_template_is_read_as_utf_8_regardless_of_locale
    write_template("dot", "a · <%= @name %>")
    old = Encoding.default_external
    begin
      Encoding.default_external = Encoding::US_ASCII
      new_app.get("/") do
        @name = "é"
        erb :dot
      end
    ensure
      Encoding.default_external = old
    end
    assert_equal html_response("a · é"), request("GET", "/")
  end

  def test_erb_with_instance_variable
    write_template("hello", "<h1>Hello, <%= @name %>!</h1>")
    new_app.get("/hello/:name") do |name|
      @name = name
      erb :hello
    end
    assert_equal html_response("<h1>Hello, world!</h1>"), request("GET", "/hello/world")
  end

  def test_erb_with_multiple_instance_variables
    write_template("profile", "<%= @user %> - <%= @role %>")
    new_app.get("/profile") do
      @user = "alice"
      @role = "admin"
      erb :profile
    end
    assert_equal html_response("alice - admin"), request("GET", "/profile")
  end

  def test_erb_raises_without_views_configured
    app = Class.new(Serviette::Application)
    app.get("/") { erb :index }
    assert_raises(RuntimeError) { app.call("REQUEST_METHOD" => "GET", "PATH_INFO" => "/") }
  end

  def test_erb_raises_for_missing_template
    new_app.get("/") { erb :nonexistent }
    error = assert_raises(RuntimeError) { request("GET", "/") }
    assert_match(/unknown template :nonexistent/, error.message)
    assert_match(/available:/, error.message)
  end

  # Layouts

  def test_layout_wraps_content
    write_template("layout", "<html><%= yield %></html>")
    write_template("index", "<p>Hello</p>")
    new_app.get("/") { erb :index }
    assert_equal html_response("<html><p>Hello</p></html>"), request("GET", "/")
  end

  def test_default_layout_auto_detected
    write_template("layout", "LAYOUT:<%= yield %>")
    write_template("page", "CONTENT")
    new_app.get("/") { erb :page }
    assert_equal html_response("LAYOUT:CONTENT"), request("GET", "/")
  end

  def test_no_layout_file_means_no_wrapping
    write_template("index", "<p>Hello</p>")
    new_app.get("/") { erb :index }
    assert_equal html_response("<p>Hello</p>"), request("GET", "/")
  end

  def test_explicit_layout
    write_template("layout", "DEFAULT:<%= yield %>")
    write_template("admin", "ADMIN:<%= yield %>")
    write_template("page", "CONTENT")
    new_app.get("/") { erb :page, layout: :admin }
    assert_equal html_response("ADMIN:CONTENT"), request("GET", "/")
  end

  def test_layout_false_skips_layout
    write_template("layout", "LAYOUT:<%= yield %>")
    write_template("page", "CONTENT")
    new_app.get("/") { erb :page, layout: false }
    assert_equal html_response("CONTENT"), request("GET", "/")
  end

  def test_layout_shares_instance_variables
    write_template("layout", "<title><%= @title %></title><%= yield %>")
    write_template("page", "<p><%= @body %></p>")
    new_app.get("/") do
      @title = "My Page"
      @body = "Hello"
      erb :page
    end
    assert_equal html_response("<title>My Page</title><p>Hello</p>"), request("GET", "/")
  end

  def test_explicit_missing_layout_raises
    write_template("page", "CONTENT")
    new_app.get("/") { erb :page, layout: :nonexistent }
    error = assert_raises(RuntimeError) { request("GET", "/") }
    assert_match(/unknown layout template :nonexistent/, error.message)
  end

  # Names that aren't valid method names

  def test_template_in_subdirectory
    write_template("users/show", "<h1><%= @name %></h1>")
    new_app.get("/users/:name") do |name|
      @name = name
      erb :"users/show"
    end
    assert_equal html_response("<h1>alice</h1>"), request("GET", "/users/alice")
  end

  def test_partial_in_subdirectory
    write_template("layout", "LAYOUT:<%= yield %>")
    write_template("users/_row", "<li><%= props[:name] %></li>")
    write_template("users/index", '<ul><%= erb :"users/_row", props: { name: "alice" } %></ul>')
    new_app.get("/") { erb :"users/index" }
    assert_equal html_response("LAYOUT:<ul><li>alice</li></ul>"), request("GET", "/")
  end

  def test_partial_keeps_content_type_set_by_route
    write_template("users/_row", "<li><%= props[:name] %></li>")
    new_app.get("/") do
      content_type "application/json"
      %({"html":"#{erb :"users/_row", props: { name: "alice" }}"})
    end
    expected = [200, {"content-type" => "application/json"}, ['{"html":"<li>alice</li>"}']]
    assert_equal expected, request("GET", "/")
  end

  def test_erb_keeps_content_type_set_before_render
    write_template("feed", "<feed/>")
    new_app.get("/") do
      content_type "application/atom+xml"
      erb :feed
    end
    assert_equal [200, {"content-type" => "application/atom+xml"}, ["<feed/>"]], request("GET", "/")
  end

  def test_content_type_after_erb_overrides_html
    write_template("index", "<h1>Hello</h1>")
    new_app.get("/") do
      body = erb :index
      content_type "text/plain"
      body
    end
    assert_equal [200, {"content-type" => "text/plain"}, ["<h1>Hello</h1>"]], request("GET", "/")
  end

  def test_template_name_with_dot
    write_template("show.html", "DOTTED")
    new_app.get("/") { erb :"show.html" }
    assert_equal html_response("DOTTED"), request("GET", "/")
  end

  def test_similar_names_do_not_collide
    write_template("users/_row", "PARTIAL")
    write_template("users_/row", "OTHER")
    new_app.get("/a") { erb :"users/_row" }
    @app.get("/b") { erb :"users_/row" }
    assert_equal html_response("PARTIAL"), request("GET", "/a")
    assert_equal html_response("OTHER"), request("GET", "/b")
  end

  # Ractor safety

  def test_erb_in_ractor
    write_template("hello", "<h1>Hello, <%= @name %>!</h1>")
    app = new_app
    app.get("/hello/:name") do |name|
      @name = name
      erb :hello
    end
    app.freeze

    result = Ractor.new(app) do |a|
      a.call("REQUEST_METHOD" => "GET", "PATH_INFO" => "/hello/world")
    end.value

    assert_equal html_response("<h1>Hello, world!</h1>"), result
  end

  def test_layout_in_ractor
    write_template("layout", "<html><%= yield %></html>")
    write_template("hello", "<p>Hello, <%= @name %>!</p>")
    app = new_app
    app.get("/hello/:name") do |name|
      @name = name
      erb :hello
    end
    app.freeze

    result = Ractor.new(app) do |a|
      a.call("REQUEST_METHOD" => "GET", "PATH_INFO" => "/hello/world")
    end.value

    assert_equal html_response("<html><p>Hello, world!</p></html>"), result
  end

  def test_erb_parallel_ractors
    write_template("greet", "Hi, <%= @name %>!")
    app = new_app
    app.get("/greet/:name") do |name|
      @name = name
      erb :greet
    end
    app.freeze

    names = %w[alice bob carol dave]
    results = names.map do |name|
      Ractor.new(app, name) do |a, n|
        a.call("REQUEST_METHOD" => "GET", "PATH_INFO" => "/greet/#{n}")
      end
    end.map(&:value)

    names.each_with_index do |name, i|
      assert_equal html_response("Hi, #{name}!"), results[i]
    end
  end
end
