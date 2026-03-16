# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "serviette"
require "rack/test"
require "rack/lint"
require "minitest/autorun"
