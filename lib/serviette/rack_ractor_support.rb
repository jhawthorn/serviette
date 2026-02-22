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
  Rack::Request.ip_filter = Ractor.shareable_proc(&Rack::Request.ip_filter)
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
