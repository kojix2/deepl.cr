require "./deepl/version"

{% if flag?(:deepl_v2) || flag?(:deepl_v3) || env("DEEPL_API_VERSION") %}
  {% raise "DEEPL_API_VERSION and -Ddeepl_v2/-Ddeepl_v3 were removed. DeepL API versions are selected by each endpoint; remove the global version setting." %}
{% end %}

# The API has mixed endpoint versions. Load the single unified surface rather
# than selecting a global API version at compile time.
require "./deepl/api"

module DeepL
end
