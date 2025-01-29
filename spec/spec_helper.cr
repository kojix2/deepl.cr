require "spec"
{% if flag?(:deepl_mock) %}
STDERR.puts " Using mock for DeepL API ".colorize.back(:magenta)
require "./crest_extension_for_mock"
{% end %}
require "../src/deepl"
