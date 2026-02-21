# frozen_string_literal: true

require 'serviette'
require 'json'

class MyApp < Serviette::Application
  START_TIME = Time.now.freeze
  FORTUNES = ["good luck", "bad luck"].freeze

  get '/' do
    [200, {'Content-Type' => 'text/plain'}, ["Hello, World!\n"]]
  end

  get '/hello' do
    [200, {'Content-Type' => 'text/html'}, ["<h1>Hello from Serviette!</h1>\n"]]
  end

  get '/hello/:name' do |name|
    [200, {'Content-Type' => 'text/plain'}, ["Hello, #{name}!\n"]]
  end

  get '/fortune' do
    fortune = FORTUNES.sample
    [200, {'Content-Type' => 'text/plain'}, [fortune]]
  end

  get '/json' do
    data = {
      message: 'Hello from Serviette',
      timestamp: Time.now.to_s,
      version: '1.0.0'
    }
    [200, {'Content-Type' => 'application/json'}, [data.to_json]]
  end

  get '/api/status' do
    status = {
      status: 'ok',
      server: 'Serviette',
      uptime: Time.now - START_TIME,
      requests_handled: rand(1000)
    }
    [200, {'Content-Type' => 'application/json'}, [JSON.pretty_generate(status)]]
  end
end
