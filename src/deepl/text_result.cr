module DeepL
  record TextResult,
    text : String,
    detected_source_language : String,
    billed_characters : Int64?
end
