require "../src/deepl"

t = DeepL::Translator.new
result = t.translate_text("こんにちは、世界！", target_lang: "EN")
puts result.detected_source_language # JA
puts result.text                     # Hello, world!
