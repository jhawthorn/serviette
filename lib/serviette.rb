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
          ERB.new(File.read(file)).def_method(mod, "#{name}(props = {})", file)
          @templates[name.to_sym] = Template.new(name, mod.instance_method(name))
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
        path_info = env['PATH_INFO']

        if (verb_routes = routes[request_method])
          verb_routes.each do |pattern, handler|
            next unless (match = pattern.match(path_info))

            instance = new(env)
            instance.params = match.named_captures.freeze
            result = instance.instance_exec(*match.captures, &handler)
            if Integer === result
              instance.response.status = result
            elsif String === result
              instance.response.body = [result]
            elsif Array === result && Integer === result.first
              instance.response.status = result.shift
              instance.response.body = result.pop
              result.each { |h| instance.response.headers.merge!(h) }
            elsif result.respond_to?(:each)
              instance.response.body = result
            end
            return instance.response.finish
          end
        end

        [404, { 'content-type' => 'text/plain' }, ["Not Found\n"]]
      end

      def freeze
        routes.each_value(&:freeze)
        routes.freeze
        super
      end

      private

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
