# frozen_string_literal: true

module Serviette
  class Application
    class << self
      def routes
        @routes ||= {}
      end

      def route(verb, path, &block)
        routes[[verb, path.freeze].freeze] = Ractor.shareable_proc(&block)
      end

      def get     path, &block = route :GET,    path, &block
      def post    path, &block = route :POST,   path, &block
      def put     path, &block = route :PUT,    path, &block
      def delete  path, &block = route :DELETE, path, &block

      def call(env)
        request_method = env['REQUEST_METHOD'].to_sym
        path_info = env['PATH_INFO']

        route_key = [request_method, path_info]
        handler = routes[route_key]

        if handler
          instance = new
          instance.instance_exec(&handler)
        else
          [404, {'Content-Type' => 'text/plain'}, ["Not Found\n"]]
        end
      end

      def freeze_routes!
        routes.freeze
        self
      end
    end

    def initialize
    end
  end
end
