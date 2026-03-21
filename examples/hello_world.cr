require "../src/deepl"

t = DeepL::Translator.new
result = t.translate_text("こんにちは、世界！", target_lang: "EN")
puts result.first.detected_source_language # JA
puts result.first.text                     # Hello, world!
