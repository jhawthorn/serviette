# frozen_string_literal: true

require 'erb'
require 'rack'
require_relative 'serviette/rack_ractor_support'

module Serviette
  class Template
    def initialize(name, method)
      @method = method
      @partial = File.basename(name).start_with?("_")
      freeze
    end

    def partial? = @partial

    def render(instance, props = {}, &block)
      @method.bind_call(instance, props, &block)
    end
  end

  class Application
    class << self
      attr_reader :templates

      def views=(path)
        mod = Module.new
        @templates = {}
        Dir.glob(File.join(path, "**/*.erb")).each do |file|
          name = file.delete_prefix("#{path}/").delete_suffix(".erb")
          method_name = template_method_name(name)
          ERB.new(File.read(file)).def_method(mod, "#{method_name}(props = {})", file)
          @templates[name.to_sym] = Template.new(name, mod.instance_method(method_name))
        end
        Ractor.make_shareable(@templates)
      end

      def routes
        @routes ||= {}
      end

      def route(verb, path, &block)
        handler = Ractor.shareable_proc(&block)
        pattern = compile_route(path)
        (routes[verb] ||= []) << [pattern, handler].freeze
      end

      def get(path, &block)    = route(:GET,    path, &block)
      def post(path, &block)   = route(:POST,   path, &block)
      def put(path, &block)    = route(:PUT,    path, &block)
      def delete(path, &block) = route(:DELETE,  path, &block)

      def call(env)
        request_method = env['REQUEST_METHOD'].to_sym
        response = dispatch(env, request_method)
        # HEAD falls back to the GET routes, after any explicit HEAD route.
        # Dropping the response body is left to Rack::Head.
        response ||= dispatch(env, :GET) if request_method == :HEAD

        response || [404, { 'content-type' => 'text/plain' }, ["Not Found\n"]]
      end

      def dispatch(env, request_method)
        path_info = env['PATH_INFO']

        if (verb_routes = routes[request_method])
          verb_routes.each do |pattern, handler|
            next unless (match = pattern.match(path_info))

            instance = new(env)
            instance.params = match.named_captures.freeze
            body = instance.instance_exec(*match.captures, &handler)
            response = instance.response

            if Array === body && Integer === body.first
              raise ArgumentError, "invalid response tuple: #{body.inspect}" if body.size > 3
              status, headers, rest = body
              response.status = status
              if Hash === headers
                response.headers.merge!(headers)
                body = rest
              else
                body = headers
              end
            elsif Integer === body
              response.status = body
              body = nil
            end

            if String === body
              response.body = [body]
            elsif body.respond_to?(:each)
              response.body = body
            end

            return response.finish
          end
        end

        nil
      end
      private :dispatch

      def freeze
        routes.each_value(&:freeze)
        routes.freeze
        super
      end

      private

      # An overly complex mapping, that gives each filename a unique and
      # recognizable method name:
      #   - "/" becomes "__"
      #   - "." becomes "_2"
      #   - anything else illegal becomes "_0" plus its hex bytes
      #   - a literal "_" becomes "_1", but only where it could otherwise be
      #     read as one of the escapes above
      # So "users/_row" becomes "template_users___row".
      def template_method_name(name)
        "template_" + name.gsub(/[^a-zA-Z0-9_]|_(?![a-zA-Z]|\z)/) do |char|
          case char
          when "/" then "__"
          when "." then "_2"
          when "_" then "_1"
          else char.bytes.map { |byte| "_0%02x" % byte }.join
          end
        end
      end

      def compile_route(path)
        return path if path.is_a?(Regexp)

        parts = path.split(/:(\w+)/)
        regex = parts.each_slice(2).map do |literal, name|
          Regexp.escape(literal) + (name ? "(?<#{name}>[^/]+)" : "")
        end.join
        /\A#{regex}\z/.freeze
      end
    end

    attr_accessor :params
    attr_reader :request, :response

    def initialize(env = {})
      @request = Rack::Request.new(env)
      @response = Rack::Response.new
    end

    def status(value = nil)
      response.status = value if value
      response.status
    end

    def headers(hash = nil)
      response.headers.merge!(hash) if hash
      response.headers
    end

    def content_type(type)
      response['content-type'] = type.to_s
    end

    def redirect(uri, status = 302)
      response.status = status
      response['location'] = uri.to_s
    end

    def not_found(body = nil)
      response.status = 404
      body
    end

    def erb(template_name, layout: nil, props: {})
      templates = self.class.templates
      raise "views directory not configured. Add `self.views = File.join(__dir__, \"views\")` to #{self.class}" unless templates
      template = templates[template_name.to_sym]
      raise "unknown template :#{template_name}, available: #{templates.keys.inspect}" unless template
      content_type "text/html; charset=utf-8"
      output = template.render(self, props)

      if layout.nil?
        layout = :layout if templates.key?(:layout) && !template.partial?
      end

      if layout
        layout_template = templates[layout.to_sym]
        raise "unknown layout template :#{layout}, available: #{templates.keys.inspect}" unless layout_template
        output = layout_template.render(self) { output }
      end

      output
    end
  end
end
