# frozen_string_literal: true

require 'erb'
require 'rack'
require_relative 'serviette/rack_ractor_support'

module Serviette
  class Application
    class << self
      attr_reader :templates

      def views=(path)
        mod = Module.new
        @templates = {}
        Dir.glob(File.join(path, "**/*.erb")).each do |file|
          name = file.delete_prefix("#{path}/").delete_suffix(".erb")
          ERB.new(File.read(file)).def_method(mod, name, file)
          @templates[name.to_sym] = mod.instance_method(name).freeze
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
            result = [result] if Integer === result || String === result
            if Array === result && Integer === result.first
              instance.response.status = result.shift
              instance.response.body = result.pop
              result.each { |h| instance.response.headers.merge!(h) }
            elsif result.respond_to?(:each)
              instance.response.body = result
            end
            return instance.response.finish
          end
        end

        [404, { 'Content-Type' => 'text/plain' }, ["Not Found\n"]]
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

    def erb(template_name)
      templates = self.class.templates
      raise "views directory not configured. Add `self.views = File.join(__dir__, \"views\")` to #{self.class}" unless templates
      method = templates[template_name.to_sym]
      raise "unknown template :#{template_name}, available: #{templates.keys.inspect}" unless method
      method.bind_call(self)
    end
  end
end
