require "../../spec/spec_helper"

module DeepLMockIntegration
  extend self

  URL = ENV["DEEPL_MOCK_URL"]? || raise <<-MESSAGE
    DEEPL_MOCK_URL is required.
    Start deepl-mock and run:
      DEEPL_MOCK_URL=http://127.0.0.1:3000 crystal spec integration/deepl_mock_spec.cr
    MESSAGE

  DEFAULT_TRANSLATION_MEMORY_ID = "a74d88fb-ed2a-4943-a664-a4512398b994"

  def translator(label : String, free : Bool = false) : DeepL::Translator
    key = "deepl-cr-#{label}-#{Time.utc.to_unix}-#{Random.rand(1_000_000_000)}"
    key += ":fx" if free
    DeepL::Translator.new(auth_key: key, server_url: URL)
  end
end
