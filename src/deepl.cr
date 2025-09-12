require "./deepl/version"

{% if flag?(:deepl_v3) || env("DEEPL_API_VERSION") == "v3" %}
  # Load V3 API surface
  require "./deepl/v3"
{% else %}
  # Load V2 API surface
  require "./deepl/v2"
{% end %}

module DeepL
end
