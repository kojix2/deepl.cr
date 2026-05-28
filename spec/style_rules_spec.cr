require "./spec_helper"

{% unless flag?(:deepl_v2) %}
  describe DeepL::StyleRuleList do
    sample_json = %({
    "style_id": "bd0a38f3-1831-440b-a8dd-2c702e2325ab",
    "name": "My Style Rules",
    "creation_time": "2025-01-01T00:00:00Z",
    "updated_time": "2025-01-02T00:00:00Z",
    "language": "en",
    "version": 13,
    "configured_rules": [
      {
        "dates_and_times": {
          "date_format": "use_dd_slash_mm_slash_yyyy"
        }
      }
    ],
    "custom_instructions": [
      {
        "label": "Currency",
        "prompt": "Use currency symbol before number",
        "source_language": "en",
        "id": "68fdb803-c013-4e67-b62e-1aad0ab519cd"
      }
    ]
  })

    it "can be deserialized from JSON" do
      style_rule = DeepL::StyleRuleList.from_json(sample_json)

      style_rule.style_id.should eq("bd0a38f3-1831-440b-a8dd-2c702e2325ab")
      style_rule.name.should eq("My Style Rules")
      style_rule.language.should eq("en")
      style_rule.version.should eq(13)
      style_rule.creation_time.should eq(Time.parse_iso8601("2025-01-01T00:00:00Z"))
      style_rule.updated_time.should eq(Time.parse_iso8601("2025-01-02T00:00:00Z"))

      style_rule.configured_rules.not_nil!.size.should eq(1)
      style_rule.custom_instructions.not_nil!.size.should eq(1)
      style_rule.custom_instructions.not_nil!.first.label.should eq("Currency")
      style_rule.custom_instructions.not_nil!.first.id.should eq("68fdb803-c013-4e67-b62e-1aad0ab519cd")
    end

    it "can deserialize a list of style rules" do
      list_json = %([
      #{sample_json}
    ])

      list = Array(DeepL::StyleRuleList).from_json(list_json)
      list.size.should eq(1)
      list.first.name.should eq("My Style Rules")
    end
  end
{% end %}
