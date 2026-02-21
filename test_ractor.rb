$LOAD_PATH.unshift File.expand_path('lib', __dir__)
require 'serviette'
require_relative 'app'

# Freeze the app class and its routes for Ractor safety
MyApp.freeze

# Test in a Ractor
r = Ractor.new(MyApp) do |app_class|
  env = {
    'REQUEST_METHOD' => 'GET',
    'PATH_INFO' => '/'
  }

  response = app_class.call(env)
  response
end

puts "Response from Ractor: #{r.value.inspect}"

# Test multiple routes in parallel
ractors = [
  ['/', 'GET'],
  ['/hello', 'GET'],
  ['/hello/world', 'GET'],
  ['/fortune', 'GET'],
  ['/json', 'GET'],
  ['/api/status', 'GET']
].map do |path, method|
  Ractor.new(MyApp, path, method) do |app_class, path_info, request_method|
    env = {
      'REQUEST_METHOD' => request_method,
      'PATH_INFO' => path_info
    }

    [path_info, app_class.call(env)]
  end
end

ractors.each do |r|
  path, response = r.value
  status, headers, body = response
  puts "#{path}: #{status} - #{body.first.inspect}"
end
