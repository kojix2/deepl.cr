require "./spec_helper"

describe DeepL::Usage do
  sample_json = %({
    "products": [
      {
        "product_type": "write",
        "api_key_character_count": 1000000,
        "character_count": 1250000
      },
      {
        "product_type": "translate",
        "api_key_character_count": 880000,
        "character_count": 900000
      }
    ],
    "api_key_character_count": 1880000,
    "api_key_character_limit": 0,
    "start_time": "2025-04-24T14:58:02Z",
    "end_time": "2025-05-24T14:58:02Z",
    "character_count": 2150000,
    "character_limit": 20000000
  })

  it "can be deserialized from JSON" do
    usage = DeepL::Usage.from_json(sample_json)

    usage.products.size.should eq(2)
    usage.api_key_character_count.should eq(1880000)
    usage.api_key_character_limit.should eq(0)
    usage.character_count.should eq(2150000)
    usage.character_limit.should eq(20000000)
    usage.start_time.should eq(Time.parse_iso8601("2025-04-24T14:58:02Z"))
    usage.end_time.should eq(Time.parse_iso8601("2025-05-24T14:58:02Z"))
  end

  it "can deserialize products correctly" do
    usage = DeepL::Usage.from_json(sample_json)

    write_product = usage.products[0]
    write_product.product_type.should eq("write")
    write_product.api_key_character_count.should eq(1000000)
    write_product.character_count.should eq(1250000)

    translate_product = usage.products[1]
    translate_product.product_type.should eq("translate")
    translate_product.api_key_character_count.should eq(880000)
    translate_product.character_count.should eq(900000)
  end

  it "can be serialized to JSON" do
    usage = DeepL::Usage.from_json(sample_json)
    serialized = usage.to_json

    # Parse back to verify structure
    reparsed = DeepL::Usage.from_json(serialized)
    reparsed.products.size.should eq(2)
    reparsed.api_key_character_count.should eq(1880000)
    reparsed.character_count.should eq(2150000)
  end

  describe DeepL::Usage::Product do
    it "can be initialized manually" do
      product = DeepL::Usage::Product.new("translate", 500000_i64, 600000_i64)

      product.product_type.should eq("translate")
      product.api_key_character_count.should eq(500000)
      product.character_count.should eq(600000)
    end

    it "can be serialized to JSON" do
      product = DeepL::Usage::Product.new("write", 100000_i64, 120000_i64)
      json = product.to_json

      reparsed = DeepL::Usage::Product.from_json(json)
      reparsed.product_type.should eq("write")
      reparsed.api_key_character_count.should eq(100000)
      reparsed.character_count.should eq(120000)
    end
  end
end
