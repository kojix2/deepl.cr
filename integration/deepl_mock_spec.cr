require "./support/deepl_mock"

describe "deepl-mock integration" do
  it "translates multiple texts and parses optional result fields" do
    translator = DeepLMockIntegration.translator("text")

    results = translator.translate_text(
      ["proton beam", "proton beam"],
      "DE",
      "EN",
      show_billed_characters: true,
      model_type: "quality_optimized",
    )

    results.map(&.text).should eq(["Protonenstrahl", "Protonenstrahl"])
    results.map(&.detected_source_language).should eq(["EN", "EN"])
    results.map(&.billed_characters).should eq([11_i64, 11_i64])
    results.map(&.model_type_used).should eq(["quality_optimized", "quality_optimized"])
  end

  it "uploads, polls, and downloads a translated document" do
    translator = DeepLMockIntegration.translator("document")
    source_path = Path[__DIR__] / "../spec/fixtures/proton_beams.txt"
    output_file = File.tempname("deepl-mock-document", ".txt")

    begin
      handle = translator.translate_document_upload(source_path, "DE", "EN")
      status = translator.translate_document_get_status(handle)
      status.id.should eq(handle.id)

      translator.translate_document_wait_until_done(
        handle,
        interval: 0.01,
        timeout: 5.seconds,
      )
      translator.translate_document_download(handle, output_file)

      File.read(output_file).should eq("Protonenstrahl\nProtonenstrahl\nProtonenstrahl")
    ensure
      File.delete?(output_file)
    end
  end

  it "reads v2 languages, Pro and Free usage, and both Write endpoints" do
    translator = DeepLMockIntegration.translator("v2-metadata")

    translator.get_source_languages.any? { |language| language.language == "EN" }.should be_true
    translator.get_target_languages.any? { |language| language.language == "DE" }.should be_true

    translator.translate_text("proton beam", "DE", "EN")
    usage = translator.get_usage.as(DeepL::UsagePro)
    usage.character_count.should eq(11_i64)
    usage.products.should_not be_empty

    free_usage = DeepLMockIntegration.translator("free-usage", free: true).get_usage
    free_usage.should be_a(DeepL::UsageFree)
    free_usage.character_limit.should eq(20_000_000_i64)

    rephrased = translator.rephrase_text("any input", "en").first
    corrected = translator.correct_text("any input", "en").first
    rephrased.text.should eq("proton beam")
    corrected.text.should eq("proton beam")
    rephrased.target_language.should eq("en-US")
    corrected.target_language.should eq("en-US")
  end

  it "runs the complete legacy glossary lifecycle" do
    translator = DeepLMockIntegration.translator("v2-glossary")
    name = "deepl.cr legacy glossary"
    entries = "proton beam\tparticle ray"

    translator.get_glossary_language_pairs.any? do |pair|
      pair.source_lang == "en" && pair.target_lang == "de"
    end.should be_true

    glossary = translator.create_glossary(name, "en", "de", entries)
    translator.list_glossaries.map(&.glossary_id).should contain(glossary.glossary_id)
    translator.get_glossary_info(glossary.glossary_id).name.should eq(name)
    translator.find_glossary_info_by_name(name).glossary_id.should eq(glossary.glossary_id)
    translator.get_glossary_entries(glossary).should contain(entries)

    translated = translator.translate_text(
      "proton beam",
      "DE",
      "EN",
      glossary_id: glossary.glossary_id,
    )
    translated.first.text.should eq("particle ray")

    translator.delete_glossary(glossary).should be_true
    expect_raises(DeepL::GlossaryNotFoundError) do
      translator.get_glossary_info(glossary.glossary_id)
    end
  end

  it "runs the multilingual glossary and dictionary lifecycle" do
    translator = DeepLMockIntegration.translator("v3-glossary")
    dictionary = DeepL::GlossaryDictionary.new(
      "en",
      "de",
      entries: "proton beam\tProtonenteilchenstrahl",
      entries_format: "tsv",
    )

    translator.get_multilingual_glossary_language_pairs.any? do |pair|
      pair.source_lang == "en" && pair.target_lang == "de"
    end.should be_true

    glossary = translator.create_multilingual_glossary(
      "deepl.cr multilingual glossary",
      [dictionary],
    )
    translator.list_multilingual_glossaries.map(&.glossary_id).should contain(glossary.glossary_id)
    translator.get_multilingual_glossary(glossary.glossary_id).name.should eq(glossary.name)

    entries = translator.get_multilingual_glossary_entries(glossary, "en", "de")
    entries.entries.should eq("proton beam\tProtonenteilchenstrahl")

    translated = translator.translate_text(
      "proton beam",
      "DE",
      "EN",
      glossary_ids: [glossary.glossary_id],
    )
    translated.first.text.should eq("Protonenteilchenstrahl")

    patched = translator.patch_multilingual_glossary(
      glossary.glossary_id,
      name: "renamed multilingual glossary",
    )
    patched.name.should eq("renamed multilingual glossary")

    updated = translator.put_multilingual_glossary_dictionary(
      glossary.glossary_id,
      "en",
      "de",
      "proton beam\tGlossarstrahl",
    )
    updated.entry_count.should eq(1)
    translator.get_multilingual_glossary_entries(
      glossary.glossary_id,
      "en",
      "de",
    ).entries.should eq("proton beam\tGlossarstrahl")

    french = translator.put_multilingual_glossary_dictionary(
      glossary.glossary_id,
      "en",
      "fr",
      "proton beam\tfaisceau de protons",
    )
    french.target_lang.should eq("fr")
    translator.delete_multilingual_glossary_dictionary(
      glossary.glossary_id,
      "en",
      "fr",
    ).should be_true

    expect_raises(DeepL::GlossaryNotFoundError) do
      translator.get_multilingual_glossary_entries(glossary.glossary_id, "en", "fr")
    end

    translator.delete_multilingual_glossary(glossary).should be_true
    expect_raises(DeepL::GlossaryNotFoundError) do
      translator.get_multilingual_glossary(glossary.glossary_id)
    end
  end

  it "reads v3 language resources and repeated include values" do
    translator = DeepLMockIntegration.translator("v3-languages")

    resources = translator.get_language_resources
    resources.map(&.name).should contain("translate_text")
    resources.map(&.name).should contain("style_rules")

    languages = translator.get_languages("translate_text", ["beta", "external"])
    german = languages.find! { |language| language.lang == "de" }
    german.usable_as_source.should be_true
    german.usable_as_target.should be_true
    german.features.has_key?("glossary").should be_true
  end

  it "runs the Style Rules and custom instruction lifecycle" do
    translator = DeepLMockIntegration.translator("style-rules")
    configured_rules = JSON.parse(%({"dates_and_times":{"calendar_era":"use_bce_and_ce"}}))

    style = translator.create_style_rule_list(
      "deepl.cr style",
      "de",
      configured_rules: configured_rules,
    )
    translator.list_style_rule_lists(detailed: true).map(&.style_id).should contain(style.style_id)
    translator.get_style_rule_list(style.style_id).name.should eq("deepl.cr style")

    renamed = translator.update_style_rule_list(style.style_id, "renamed deepl.cr style")
    renamed.name.should eq("renamed deepl.cr style")

    replacement_rules = JSON.parse(%({"dates_and_times":{"calendar_era":"use_bc_and_ad"}}))
    updated_style = translator.update_style_rule_configured_rules(style.style_id, replacement_rules)
    updated_style.configured_rules.should eq(replacement_rules)

    instruction = translator.create_custom_instruction(
      style.style_id,
      "Terminology",
      "Prefer API over interface",
      "en",
    )
    instruction_id = instruction.id || raise "deepl-mock returned a custom instruction without an ID"
    translator.get_custom_instruction(style.style_id, instruction_id).prompt.should eq(instruction.prompt)

    updated_instruction = translator.update_custom_instruction(
      style.style_id,
      instruction_id,
      "Updated terminology",
      "Prefer SDK over client",
      "en",
    )
    updated_instruction.label.should eq("Updated terminology")
    updated_instruction.prompt.should eq("Prefer SDK over client")

    translator.delete_custom_instruction(style.style_id, instruction_id).should be_nil
    expect_raises(DeepL::RequestError) do
      translator.get_custom_instruction(style.style_id, instruction_id)
    end

    translator.delete_style_rule_list(style.style_id).should be_nil
    translator.list_style_rule_lists.map(&.style_id).should_not contain(style.style_id)
  end

  it "lists, retrieves, pages, and filters the default translation memory" do
    translator = DeepLMockIntegration.translator("translation-memory")
    memory_id = DeepLMockIntegration::DEFAULT_TRANSLATION_MEMORY_ID

    memories = translator.list_translation_memories(page: 0, page_size: 10)
    memories.total_count.should eq(1)
    memories.translation_memories.map(&.translation_memory_id).should contain(memory_id)

    memory = translator.get_translation_memory(memory_id)
    memory.name.should eq("Default Translation Memory")
    memory.segment_count.should eq(12_i64)

    first_page = translator.list_translation_memory_segments(memory_id, page_size: 5)
    first_page.segments.size.should eq(5)
    first_page.segment_count.should eq(12_i64)
    first_page.next_page_cursor.should_not be_nil
    first_page.segments.first.last_used_time.should_not be_nil
    first_page.segments[1].last_used_time.should be_nil

    second_page = translator.list_translation_memory_segments(
      memory_id,
      page_size: 5,
      page_cursor: first_page.next_page_cursor,
    )
    second_page.segments.size.should eq(5)
    second_page.segments.first.source_segment_id.should_not eq(first_page.segments.first.source_segment_id)

    filtered = translator.list_translation_memory_segments(
      memory_id,
      filter_text: "Nummer 7",
      filter_case_sensitive: true,
    )
    filtered.segments.size.should eq(1)
    filtered.segments.first.source_text.should eq("Quelltext Nummer 7")
  end

  it "maps invalid mock credentials to AuthorizationError with a trace ID" do
    translator = DeepL::Translator.new(
      auth_key: "invalid",
      server_url: DeepLMockIntegration::URL,
    )

    error = expect_raises(DeepL::AuthorizationError) do
      translator.translate_text("proton beam", "DE", "EN")
    end
    error.trace_id.should_not be_nil
    error.trace_id.to_s.should match(/\A[0-9a-f]{32}\z/i)
    translator.last_trace_id.should eq(error.trace_id)
  end
end
