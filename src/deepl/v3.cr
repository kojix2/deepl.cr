require "./translator"
require "./exceptions"

# V3 Translator modules

require "./v2/text"
require "./v2/document"
require "./v2/usage"
require "./v2/language"
require "./v2/rephrase"

# V3 specific modules
require "./v3/glossary"

module DeepL
  class Translator
    def resolve_glossary_id_from_name(name : String) : String
      find_multilingual_glossary_by_name(name).glossary_id
    end
  end
end
