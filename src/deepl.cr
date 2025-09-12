require "./deepl/version"

{% if flag?(:deepl_v2) || env("DEEPL_API_VERSION") == "v2" %}
  # Load V2 API surface
  require "./deepl/v2"
{% elsif flag?(:deepl_v3) || env("DEEPL_API_VERSION") == "v3" %}
  # Load V3 API surface
  require "./deepl/v3"
{% else %}
  # Load V3 API surface (default)
  require "./deepl/v3"
{% end %}

module DeepL
end
