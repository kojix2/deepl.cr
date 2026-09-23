require "spec"
{% if flag?(:deepl_mock) %}
  ENV["DEEPL_AUTH_KEY"] = "mock"
{% end %}
require "../src/deepl"
