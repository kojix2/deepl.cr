require "./spec_helper"

describe DeepL::DocumentHandle do
  it "can be serialized to JSON" do
    handle = DeepL::DocumentHandle.new("123", "abc")
    json = handle.to_json
    json.should eq(%({"document_id":"123","document_key":"abc"}))
  end

  it "can be deserialized from JSON" do
    json = %({"document_id":"123","document_key":"abc"})
    handle = DeepL::DocumentHandle.from_json(json)
    handle.id.should eq("123")
    handle.key.should eq("abc")
  end
end
