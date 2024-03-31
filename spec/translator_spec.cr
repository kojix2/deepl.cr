require "./spec_helper"

describe DeepL::Translator do
  it "can get deepl api key from environment variable" do
    dummy_api_key = "dummy_env_key"
    ENV["DEEPL_AUTH_KEY"] = dummy_api_key
    t = DeepL::Translator.new
    t.auth_key.should eq(dummy_api_key)
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
end
