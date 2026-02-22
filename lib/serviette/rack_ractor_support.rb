# frozen_string_literal: true

# Freeze Rack constants so that they are shareable between Ractors.
# This file can be required after Rack is loaded to make it Ractor-safe
# without needing changes to Rack's source.

# Rack::Auth
Rack::Auth::AbstractRequest::AUTHORIZATION_KEYS.freeze

# Rack::Files
Rack::Files::ALLOWED_VERBS.freeze
Rack::Files::ALLOW_HEADER.freeze
Rack::Files::MULTIPART_BOUNDARY.freeze

# Rack::Headers
Rack::Headers::KNOWN_HEADERS.freeze

# Rack::Lint
Rack::Lint::Wrapper::BODY_METHODS.freeze
Rack::Lint::Wrapper::StreamWrapper::REQUIRED_METHODS.freeze

# Rack::Mime
Rack::Mime::MIME_TYPES.freeze

# Rack::ShowExceptions
Ractor.make_shareable(Rack::ShowExceptions::TEMPLATE)

# Rack::Multipart::Parser
if Rack::Multipart::Parser::TEMPFILE_FACTORY.is_a?(Proc) && !Ractor.shareable?(Rack::Multipart::Parser::TEMPFILE_FACTORY)
  old_tempfile_factory = Rack::Multipart::Parser::TEMPFILE_FACTORY
  Rack::Multipart::Parser.send(:remove_const, :TEMPFILE_FACTORY)
  Rack::Multipart::Parser::TEMPFILE_FACTORY = Ractor.shareable_proc(&old_tempfile_factory)
end
Rack::Multipart::Parser::EMPTY.tmp_files.freeze
Rack::Multipart::Parser::EMPTY.freeze

# Rack::QueryParser
Rack::QueryParser::COMMON_SEP.freeze
Rack::Utils.default_query_parser.freeze

# Rack::Request
if Rack::Request.ip_filter.is_a?(Proc) && !Ractor.shareable?(Rack::Request.ip_filter)
  # Rack's ip_filter lambda captures a local `trusted_proxies` regex that
  # isn't shareable, so shareable_proc can't convert it.  Rebuild it with
  # a shareable copy of the same pattern.
  valid_ipv4_octet = /\.(25[0-5]|2[0-4][0-9]|[01]?[0-9]?[0-9])/
  trusted_proxies = Ractor.make_shareable(Regexp.union(
    /\A127#{valid_ipv4_octet}{3}\z/,
    /\A::1\z/,
    /\Af[cd][0-9a-f]{2}(?::[0-9a-f]{0,4}){0,7}\z/i,
    /\A10#{valid_ipv4_octet}{3}\z/,
    /\A172\.(1[6-9]|2[0-9]|3[01])#{valid_ipv4_octet}{2}\z/,
    /\A192\.168#{valid_ipv4_octet}{2}\z/,
    /\Alocalhost\z|\Aunix(\z|:)/i,
  ))
  Rack::Request.ip_filter = Ractor.shareable_proc { |ip| trusted_proxies.match?(ip) }
end
Rack::Request::Helpers::DEFAULT_PORTS.freeze
Rack::Request::Helpers::FORM_DATA_MEDIA_TYPES.freeze
Rack::Request::Helpers::PARSEABLE_DATA_MEDIA_TYPES.freeze
Rack::Request.forwarded_priority.freeze
Rack::Request.x_forwarded_proto_priority.freeze

# Rack::Utils
Rack::Utils::HTTP_STATUS_CODES.freeze
Rack::Utils::STATUS_WITH_NO_ENTITY_BODY.freeze
Rack::Utils::SYMBOL_TO_STATUS_CODE.freeze
