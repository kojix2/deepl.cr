require "spec"
{% if flag?(:deepl_mock) %}
  {% raise "-Ddeepl_mock was removed. Start deepl-mock and run DEEPL_MOCK_URL=http://127.0.0.1:3000 crystal spec integration/deepl_mock_spec.cr instead." %}
{% end %}
require "../src/deepl"
