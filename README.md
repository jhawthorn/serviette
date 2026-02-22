# Serviette

> [!WARNING]
> Serviette is experimental and under active development. APIs may change without notice.

A minimal, Ractor-safe web framework for Ruby 4.0.

Inspired by Sinatra, Serviette provides a simple DSL for declaring route
handlers.

## Usage

```ruby
require 'serviette'

class MyApp < Serviette::Application
  get '/' do
    "Hello, World!"
  end

  get '/hello/:name' do |name|
    "Hello, #{name}!"
  end

  get '/users/:id' do
    [200, { 'Content-Type' => 'application/json' }, [{ id: params["id"] }.to_json]]
  end
end

# config.ru
run MyApp
```

Route handlers can return a string (automatically wrapped as a 200 response)
or a standard Rack `[status, headers, body]` tuple.

## Views

ERB templates are precompiled at boot and made Ractor-shareable.

```ruby
class MyApp < Serviette::Application
  self.views = File.join(__dir__, "views")

  get '/' do
    @title = "Home"
    erb :index
  end
end
```
