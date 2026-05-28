require "./spec_helper"

{% unless flag?(:deepl_v2) %}
  describe DeepL::LanguageResource do
    it "can be deserialized from JSON" do
      resources = Array(DeepL::LanguageResource).from_json(<<-JSON)
        [
          {
            "name": "translate_text",
            "features": [
              {
                "name": "formality",
                "needs_target_support": true
              }
            ]
          }
        ]
        JSON

      resources.first.name.should eq("translate_text")
      resources.first.features.first.name.should eq("formality")
      resources.first.features.first.needs_target_support.should be_true
      resources.first.features.first.needs_source_support.should be_nil
    end
  end

  describe DeepL::ResourceLanguage do
    it "can be deserialized from JSON" do
      languages = Array(DeepL::ResourceLanguage).from_json(<<-JSON)
        [
          {
            "lang": "de",
            "name": "German",
            "usable_as_source": true,
            "usable_as_target": true,
            "status": "stable",
            "features": {
              "formality": {
                "status": "stable"
              }
            }
          }
        ]
        JSON

      languages.first.lang.should eq("de")
      languages.first.name.should eq("German")
      languages.first.usable_as_source.should be_true
      languages.first.usable_as_target.should be_true
      languages.first.status.should eq("stable")
      languages.first.features["formality"]["status"].as_s.should eq("stable")
    end
  end
{% end %}
