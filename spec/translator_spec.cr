require "./spec_helper"

# Change private methods to public for testing

class DeepL::Translator
  def generate_output_file(source_path : Path, target_lang, output_format) : Path
    previous_def
  end

  def ensure_unique_output_file(output_file : Path) : Path
    previous_def
  end
end

describe DeepL::Translator do
  it "has default deepl server url" do
    DeepL::Translator::DEEPL_SERVER_URL.should \
      eq("#{ENV.fetch("DEEPL_SERVER_URL", "https://api.deepl.com")}/v2")
    DeepL::Translator::DEEPL_SERVER_URL_FREE.should \
      eq("#{ENV.fetch("DEEPL_SERVER_URL_FREE", "https://api-free.deepl.com")}/v2")
  end

  it "cannot change deepl server url at runtime" do
    original_server_url = ENV["DEEPL_SERVER_URL"]?
    ENV["DEEPL_SERVER_URL"] = "https://example.com"
    t = DeepL::Translator.new
    t.server_url.should_not contain("example.com")
    if original_server_url
      ENV["DEEPL_SERVER_URL"] = original_server_url
    else
      ENV.delete("DEEPL_SERVER_URL")
    end
  end

  it "can get deepl api key from environment variable" do
    dummy_api_key = "dummy_env_key"
    original_api_key = ENV["DEEPL_AUTH_KEY"]?
    ENV["DEEPL_AUTH_KEY"] = dummy_api_key
    t = DeepL::Translator.new
    t.auth_key.should eq(dummy_api_key)
    # ENV.delete("DEEPL_AUTH_KEY")
    if original_api_key
      ENV["DEEPL_AUTH_KEY"] = original_api_key
    else
      ENV.delete("DEEPL_AUTH_KEY")
    end
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

  it "can set user agent" do
    dummy_user_agent = "dummy_user_agent"
    t = DeepL::Translator.new(user_agent: dummy_user_agent)
    t.user_agent.should eq(dummy_user_agent)
  end

  it "can set user agent from environment variable" do
    original_user_agent = ENV["DEEPL_USER_AGENT"]?
    dummy_user_agent = "dummy_env_user_agent"
    ENV["DEEPL_USER_AGENT"] = dummy_user_agent
    t = DeepL::Translator.new
    t.user_agent.should eq(dummy_user_agent)
    if original_user_agent
      ENV["DEEPL_USER_AGENT"] = original_user_agent
    else
      ENV.delete("DEEPL_USER_AGENT")
    end
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
    output_file = t.generate_output_file(source_path, target_lang, output_format)
    output_file.should eq(Path[__DIR__] / "fixtures" / "sample_PT-BR.docx")
  end

  it "can ensure unique output path" do
    t = DeepL::Translator.new
    source_path = Path[__DIR__] / "fixtures" / "sample.pdf"
    target_lang = "PT-BR"
    output_format = "txt"
    output_file = t.generate_output_file(source_path, target_lang, output_format)
    output_file.parent.should eq(Path[__DIR__] / "fixtures")
    output_file.basename.to_s.should match(/sample_PT-BR_\d{10}.txt/)
  end

  {% if flag?(:deepl_mock) %}
    it "can translate text using mock" do
      t = DeepL::Translator.new
      r = t.translate_text("proton beam", "DE", "EN").first
      r.detected_source_language.should eq("EN")
      r.text.should eq("Protonenstrahl")
    end

    it "can translate document using mock" do
      t = DeepL::Translator.new
      source_path = Path[__DIR__] / "fixtures" / "proton_beams.txt"
      target_lang = "DE"
      output_file = Path[__DIR__] / "fixtures" / "proton_beams_DE.txt"
      t.translate_document(source_path, target_lang, output_file: output_file)
      output_text = File.read(output_file)
      output_text.should eq("Protonenstrahl\nProtonenstrahl\nProtonenstrahl")
    end

    it "can translate document step by step using mock" do
      t = DeepL::Translator.new
      source_path = Path[__DIR__] / "fixtures" / "proton_beams.txt"
      output_file = Path[__DIR__] / "fixtures" / "proton_beams_DE.txt"
      target_lang = "DE"
      dh = t.translate_document_upload(source_path, target_lang)
      dh.should be_a(DeepL::DocumentHandle)

      ds = t.translate_document_get_status(dh)
      ds.should be_a(DeepL::DocumentStatus)

      t.translate_document_wait_until_done(dh)
      t.translate_document_download(dh, output_file)

      output_text = File.read(output_file)
      output_text.should eq("Protonenstrahl\nProtonenstrahl\nProtonenstrahl")
    end

    it "it can get target languages using mock" do
      t = DeepL::Translator.new
      r = t.get_target_languages
      r.should be_a(Array(DeepL::LanguageInfo))
    end

    it "it can get source languages using mock" do
      t = DeepL::Translator.new
      r = t.get_source_languages
      r.should be_a(Array(DeepL::LanguageInfo))
    end
  {% end %}
end
