require "./exceptions"
require "./translator"

# Endpoint versions are local to their modules. Both families are available
# from the ordinary `require "deepl"` entry point.
require "./v2/text"
require "./v2/document"
require "./v2/glossary"
require "./v2/usage"
require "./v2/language"
require "./v2/rephrase"
require "./v2/admin"

require "./v3/glossary"
require "./v3/language"
require "./v3/style_rules"
require "./v3/translation_memory"
require "./v3/voice"
