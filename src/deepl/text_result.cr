module DeepL
  record TextResult,
    text : String,
    detected_source_language : String,
    billed_characters : UInt64
end
