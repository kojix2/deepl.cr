require "./spec_helper"

# Change private methods to public for testing

class DeepL::Translator
  def generate_output_path(source_path : Path, target_lang, output_format) : Path
    previous_def
  end

  def ensure_unique_output_path(output_path : Path) : Path
    previous_def
  end
end

describe DeepL::Translator do
  it "can get deepl api key from environment variable" do
    dummy_api_key = "dummy_env_key"
    ENV["DEEPL_AUTH_KEY"] = dummy_api_key
    t = DeepL::Translator.new
    t.auth_key.should eq(dummy_api_key)
    ENV.delete("DEEPL_AUTH_KEY")
  end

  it "can set deepl api key" do
    dummy_api_key = "dummy_arg_key"
    t = DeepL::Translator.new(auth_key: dummy_api_key)
    t.auth_key.should eq(dummy_api_key)
  end

  it "has default user agent" do
    t = DeepL::Translator.new
    t.user_agent.should eq("deepl.cr/#{DeepL::VERSION}")
  end

  it "can guess target language from environment variable" do
    ENV["DEEPL_TARGET_LANG"] = "CRYSTAL"
    t = DeepL::Translator.new
    t.guess_target_language.should eq("CRYSTAL")
    ENV.delete("DEEPL_TARGET_LANG")
  end

  it "can guess target language" do
    t = DeepL::Translator.new
    t.guess_target_language.should be_a(String)
  end

  it "can generate output path" do
    t = DeepL::Translator.new
    source_path = Path[__DIR__] / "fixtures" / "sample.txt"
    target_lang = "PT-BR"
    output_format = "docx"
    output_path = t.generate_output_path(source_path, target_lang, output_format)
    output_path.should eq(Path[__DIR__] / "fixtures" / "sample_PT-BR.docx")
  end

  it "can ensure unique output path" do
    t = DeepL::Translator.new
    source_path = Path[__DIR__] / "fixtures" / "sample.pdf"
    target_lang = "PT-BR"
    output_format = "txt"
    output_path = t.generate_output_path(source_path, target_lang, output_format)
    output_path.parent.should eq(Path[__DIR__] / "fixtures")
    output_path.basename.to_s.should match(/sample_PT-BR_\d{10}.txt/)
  end
end
