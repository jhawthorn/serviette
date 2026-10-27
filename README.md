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
    redirect '/hello/world'
  end

  get '/hello/:name' do |name|
    "Hello, #{name}!"
  end

  get '/users/:id' do
    content_type 'application/json'
    { id: params["id"] }.to_json
  end
end

# config.ru
run MyApp
```

Route handlers can return a string (automatically wrapped as a 200 response),
an integer status, or a Rack `[status, headers, body]` tuple with either the
headers or the body left out. Helpers like `status`, `headers`, `content_type`,
`redirect`, and `not_found` are available.

To customize 404s, register a handler with `not_found { |message| ... }`. It
renders unmatched paths and `not_found(message)` calls, and can use `erb`:

```ruby
not_found { |message| erb :not_found, props: { message: message } }
```

## Views

ERB templates are precompiled at boot and made Ractor-shareable. A
`layout.erb` is automatically used if present (override with `layout:` or
disable with `layout: false`).

```ruby
class MyApp < Serviette::Application
  self.views = File.join(__dir__, "views")

  get '/' do
    @title = "Home"
    erb :index
  end
end
```
