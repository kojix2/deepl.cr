require "./translator"
require "./exceptions"

# Translator modules

require "./v2/text"
require "./v2/document"
require "./v2/glossary"
require "./v2/usage"
require "./v2/language"
require "./v2/rephrase"

module DeepL
  class Translator
    def resolve_glossary_id_from_name(name : String) : String
      find_glossary_info_by_name(name).glossary_id
    end
  end
end
