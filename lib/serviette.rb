# frozen_string_literal: true

module Serviette
  class Application
    class << self
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
            return instance.instance_exec(*match.captures, &handler)
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
  end
end
