# frozen_string_literal: true

require 'erb'

module Serviette
  class Application
    class << self
      attr_accessor :views

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

            instance = new
            instance.params = match.named_captures.freeze
            response = instance.instance_exec(*match.captures, &handler)
            case response
            when String
              return [200, {}, [response]]
            else
              return response
            end
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

    def initialize
    end

    def erb(template_name)
      views = self.class.views
      raise "views directory not configured. Add `self.views = File.join(__dir__, \"views\")` to #{self.class}" unless views
      path = File.join(views, "#{template_name}.erb")
      ERB.new(File.read(path)).result(binding)
    end
  end
end
