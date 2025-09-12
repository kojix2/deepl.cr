require "./spec_helper"

{% unless flag?(:deepl_v3) || env("DEEPL_API_VERSION") == "v3" %}
  describe DeepL::GlossaryInfo do
    it "can be serialized to JSON" do
      tm = Time.utc
      info = DeepL::GlossaryInfo.new("glossary_id", "Glossary", true, "en", "fr", tm, 10)
      json = info.to_json
      json.should eq(%({"glossary_id":"glossary_id","name":"Glossary","ready":true,"source_lang":"en","target_lang":"fr","creation_time":"#{tm.to_rfc3339}","entry_count":10}))
    end

    it "can be deserialized from JSON" do
      tm = Time.utc.to_rfc3339
      json = %({"glossary_id":"glossary_id","name":"Glossary","ready":true,"source_lang":"en","target_lang":"fr","creation_time":"#{tm}","entry_count":10})
      info = DeepL::GlossaryInfo.from_json(json)
      info.glossary_id.should eq("glossary_id")
      info.name.should eq("Glossary")
      info.ready.should eq(true)
      info.source_lang.should eq("en")
      info.target_lang.should eq("fr")
      info.creation_time.should eq(Time.parse_iso8601(tm))
      info.entry_count.should eq(10)
      info.to_json.should eq(json)
    end
  end
{% end %}
