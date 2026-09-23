require "./spec_helper"
require "./support/recording_server"

describe DeepL::TranslationMemoryList do
  sample_json = <<-JSON
    {
      "translation_memories": [
        {
          "translation_memory_id": "a74d88fb-ed2a-4943-a664-a4512398b994",
          "name": "Legal",
          "source_language": "en",
          "target_languages": ["es", "de"],
          "segment_count": 3542
        }
      ],
      "total_count": 1
    }
    JSON

  it "can be deserialized from JSON" do
    list = DeepL::TranslationMemoryList.from_json(sample_json)

    list.total_count.should eq(1)
    list.translation_memories.size.should eq(1)
    list.translation_memories.first.translation_memory_id.should eq("a74d88fb-ed2a-4943-a664-a4512398b994")
    list.translation_memories.first.target_languages.should eq(["es", "de"])
    list.translation_memories.first.segment_count.should eq(3542)
  end
end

describe "translation memory endpoints" do
  it "retrieves a translation memory" do
    body = <<-JSON
      {
        "translation_memory_id": "memory-id",
        "name": "Legal",
        "source_language": "en",
        "target_languages": ["de"],
        "segment_count": 12,
        "creation_time": "2026-04-01T16:34:25.223Z",
        "updated_time": "2026-08-06T09:12:44.108Z"
      }
      JSON
    server = RecordingServer.new([
      RecordingServer::ScriptedResponse.new(
        200,
        body: body,
        headers: {"Content-Type" => "application/json"}
      ),
    ])

    begin
      translator = DeepL::Translator.new("translation-memory-test-key", nil, server.url)
      memory = translator.get_translation_memory("memory-id")

      memory.name.should eq("Legal")
      memory.segment_count.should eq(12)
      memory.creation_time.should eq(Time.parse_iso8601("2026-04-01T16:34:25.223Z"))
      memory.updated_time.should eq(Time.parse_iso8601("2026-08-06T09:12:44.108Z"))
      server.requests.map(&.resource).should eq(["/v3/translation_memories/memory-id"])
    ensure
      server.close
    end
  end

  it "lists cursor-paginated translation memory segments" do
    body = <<-JSON
      {
        "segments": [
          {
            "source_segment_id": "source-id",
            "source_text": "This agreement applies.",
            "creation_time": "2026-04-01T16:34:25.223Z",
            "updated_time": "2026-04-02T16:34:25.223Z",
            "last_used_time": "2026-08-05T11:02:18.771Z",
            "targets": [
              {
                "target_segment_id": "target-id",
                "target_language": "de",
                "target_text": "Diese Vereinbarung gilt.",
                "creation_time": "2026-04-01T16:34:25.223Z",
                "updated_time": "2026-04-02T16:34:25.223Z",
                "last_used_time": "2026-08-05T11:02:18.771Z"
              }
            ]
          }
        ],
        "segment_count": 3542,
        "next_page_cursor": "next-cursor"
      }
      JSON
    server = RecordingServer.new([
      RecordingServer::ScriptedResponse.new(
        200,
        body: body,
        headers: {"Content-Type" => "application/json"}
      ),
    ])

    begin
      translator = DeepL::Translator.new("translation-memory-test-key", nil, server.url)
      result = translator.list_translation_memory_segments(
        "memory-id",
        page_size: 25,
        page_cursor: "previous-cursor",
        filter_text: "agreement",
        filter_case_sensitive: true,
      )

      result.segment_count.should eq(3542)
      result.next_page_cursor.should eq("next-cursor")
      result.segments.first.source_text.should eq("This agreement applies.")
      result.segments.first.last_used_time.should eq(Time.parse_iso8601("2026-08-05T11:02:18.771Z"))
      target = result.segments.first.targets.first
      target.target_language.should eq("de")
      target.target_text.should eq("Diese Vereinbarung gilt.")
      target.last_used_time.should eq(Time.parse_iso8601("2026-08-05T11:02:18.771Z"))
      server.requests.map(&.resource).should eq([
        "/v3/translation_memories/memory-id/segments?page_size=25&page_cursor=previous-cursor&filter_text=agreement&filter_case_sensitive=true",
      ])
    ensure
      server.close
    end
  end

  it "deserializes import, export, and job responses" do
    import_job = DeepL::TranslationMemoryImport.from_json(<<-JSON)
      {
        "job_id": "import-job",
        "upload_url": "https://assets.example.test/upload",
        "expires_at": "2026-08-06T15:34:25.223Z"
      }
      JSON
    export_job = DeepL::TranslationMemoryExport.from_json(<<-JSON)
      {
        "job_id": "export-job",
        "parameters": {"translation_memory_id": "memory-id"}
      }
      JSON
    job = DeepL::TranslationMemoryJob.from_json(<<-JSON)
      {
        "job_id": "import-job",
        "product": "translation_memory",
        "operation": "import",
        "creation_time": "2026-08-06T15:04:25.223Z",
        "updated_time": "2026-08-06T15:06:11.418Z",
        "source_file": {"content_type": "application/xml", "content_length": 1024},
        "parameters": {"display_name": "Legal"},
        "results": [{
          "status": "completed",
          "translation_memory_id": "memory-id",
          "skipped_segment_count": 12
        }]
      }
      JSON

    import_job.upload_url.should eq("https://assets.example.test/upload")
    export_job.parameters.translation_memory_id.should eq("memory-id")
    job.source_file.try(&.content_length).should eq(1024_i64)
    job.parameters.display_name.should eq("Legal")
    job.results.first.translation_memory_id.should eq("memory-id")
    job.results.first.skipped_segment_count.should eq(12_i64)
  end

  it "imports, exports, and deletes translation memories through signed URLs" do
    source_path = File.tempname("deepl-translation-memory", ".tmx")
    output_path = File.tempname("deepl-translation-memory", ".tmx")
    File.write(source_path, "<tmx version=\"1.4\"/>")

    asset_server = RecordingServer.new([
      RecordingServer::ScriptedResponse.new(200),
      RecordingServer::ScriptedResponse.new(200, "<tmx>exported</tmx>"),
    ])
    api_server = RecordingServer.new([
      RecordingServer::ScriptedResponse.new(
        202,
        %({"job_id":"import-job","upload_url":"#{asset_server.url}/upload","expires_at":"2026-08-06T15:34:25.223Z"}),
      ),
      RecordingServer::ScriptedResponse.new(
        200,
        %({"job_id":"import-job","product":"translation_memory","operation":"import","creation_time":"2026-08-06T15:04:25.223Z","updated_time":"2026-08-06T15:06:11.418Z","parameters":{"display_name":"Legal"},"results":[{"status":"completed","translation_memory_id":"imported-memory","skipped_segment_count":0}]}),
      ),
      RecordingServer::ScriptedResponse.new(
        202,
        %({"job_id":"export-job","parameters":{"translation_memory_id":"imported-memory"}}),
      ),
      RecordingServer::ScriptedResponse.new(
        200,
        %({"job_id":"export-job","product":"translation_memory","operation":"export","creation_time":"2026-08-06T15:04:25.223Z","updated_time":"2026-08-06T15:06:11.418Z","parameters":{"translation_memory_id":"imported-memory"},"results":[{"status":"completed","download_url":"#{asset_server.url}/download","expires_at":"2026-08-06T16:05:02.771Z"}]}),
      ),
      RecordingServer::ScriptedResponse.new(204),
    ])

    begin
      translator = DeepL::Translator.new(auth_key: "test-key", server_url: api_server.url)
      imported = translator.import_translation_memory(
        source_path,
        display_name: "Legal",
        interval: 0.001,
      )
      imported.results.first.translation_memory_id.should eq("imported-memory")

      exported = translator.export_translation_memory(
        "imported-memory",
        output_path,
        interval: 0.001,
      )
      exported.results.first.download_url.should eq("#{asset_server.url}/download")
      File.read(output_path).should eq("<tmx>exported</tmx>")
      translator.delete_translation_memory("imported-memory").should be_true

      api_server.requests.map(&.resource).should eq([
        "/v3/translation_memories/import",
        "/v3/translation_memories/jobs/import-job",
        "/v3/translation_memories/imported-memory/export",
        "/v3/translation_memories/jobs/export-job",
        "/v3/translation_memories/imported-memory",
      ])
      asset_server.requests.map(&.resource).should eq(["/upload", "/download"])
      asset_server.requests.each do |request|
        request.headers.has_key?("Authorization").should be_false
      end
      asset_server.requests.first.headers["Content-Length"].should eq(File.size(source_path).to_s)
      JSON.parse(api_server.requests.first.body)["source_file"]["file_name"].as_s.should eq(File.basename(source_path))
      JSON.parse(api_server.requests.first.body)["parameters"]["display_name"].as_s.should eq("Legal")
    ensure
      api_server.close
      asset_server.close
      File.delete?(source_path)
      File.delete?(output_path)
    end
  end

  it "waits through non-terminal jobs and exposes each poll" do
    processing = %({"job_id":"job-id","product":"translation_memory","operation":"export","creation_time":"2026-08-06T15:04:25.223Z","updated_time":"2026-08-06T15:04:25.223Z","parameters":{"translation_memory_id":"memory-id"},"results":[{"status":"processing"}]})
    completed = %({"job_id":"job-id","product":"translation_memory","operation":"export","creation_time":"2026-08-06T15:04:25.223Z","updated_time":"2026-08-06T15:06:11.418Z","parameters":{"translation_memory_id":"memory-id"},"results":[{"status":"completed","download_url":"https://assets.example.test/download"}]})
    server = RecordingServer.new([
      RecordingServer::ScriptedResponse.new(200, processing),
      RecordingServer::ScriptedResponse.new(200, completed),
    ])

    begin
      statuses = [] of String
      job = DeepL::Translator.new(auth_key: "test-key", server_url: server.url)
        .wait_for_translation_memory_job("job-id", interval: 0.001) do |polled_job|
          statuses << polled_job.results.first.status
        end

      job.results.first.status.should eq("completed")
      statuses.should eq(["processing", "completed"])
      server.requests.map(&.resource).should eq([
        "/v3/translation_memories/jobs/job-id",
        "/v3/translation_memories/jobs/job-id",
      ])
    ensure
      server.close
    end
  end

  it "retries transient job-status responses while polling" do
    completed = %({"job_id":"job-id","product":"translation_memory","operation":"export","creation_time":"2026-08-06T15:04:25.223Z","updated_time":"2026-08-06T15:06:11.418Z","parameters":{"translation_memory_id":"memory-id"},"results":[{"status":"completed","download_url":"https://assets.example.test/download"}]})
    server = RecordingServer.new([
      RecordingServer::ScriptedResponse.new(429),
      RecordingServer::ScriptedResponse.new(200, completed),
    ])

    begin
      job = DeepL::Translator.new(auth_key: "test-key", server_url: server.url)
        .wait_for_translation_memory_job("job-id", interval: 0.001)

      job.results.first.status.should eq("completed")
      server.requests.size.should eq(2)
    ensure
      server.close
    end
  end

  it "raises TranslationMemoryJobError for terminal failure, expiration, and timeout" do
    ["failed", "expired"].each do |status|
      body = %({"job_id":"job-id","product":"translation_memory","operation":"import","creation_time":"2026-08-06T15:04:25.223Z","updated_time":"2026-08-06T15:06:11.418Z","parameters":{},"results":[{"status":"#{status}","error":{"message":"job #{status}"}}]})
      server = RecordingServer.new([RecordingServer::ScriptedResponse.new(200, body)])

      begin
        error = expect_raises(DeepL::TranslationMemoryJobError) do
          DeepL::Translator.new(auth_key: "test-key", server_url: server.url)
            .wait_for_translation_memory_job("job-id")
        end
        error.message.should eq("job #{status}")
        error.job.try(&.job_id).should eq("job-id")
      ensure
        server.close
      end
    end

    timeout_error = expect_raises(DeepL::TranslationMemoryJobError) do
      DeepL::Translator.new(auth_key: "test-key", server_url: "http://127.0.0.1:1")
        .wait_for_translation_memory_job("job-id", timeout: Time::Span.zero)
    end
    timeout_error.message.to_s.should contain("timed out")
    timeout_error.job.should be_nil

    processing = %({"job_id":"job-id","product":"translation_memory","operation":"export","creation_time":"2026-08-06T15:04:25.223Z","updated_time":"2026-08-06T15:04:25.223Z","parameters":{"translation_memory_id":"memory-id"},"results":[{"status":"processing"}]})
    server = RecordingServer.new([RecordingServer::ScriptedResponse.new(200, processing)])
    begin
      timeout_error = expect_raises(DeepL::TranslationMemoryJobError) do
        DeepL::Translator.new(auth_key: "test-key", server_url: server.url)
          .wait_for_translation_memory_job("job-id", interval: 1.0, timeout: 0.01.seconds)
      end
      timeout_error.job.try(&.job_id).should eq("job-id")
    ensure
      server.close
    end
  end

  it "does not overwrite an existing export file when a signed download fails" do
    output_path = File.tempname("deepl-translation-memory", ".tmx")
    File.write(output_path, "existing export")
    asset_server = RecordingServer.new([
      RecordingServer::ScriptedResponse.new(500, "signed download failed"),
    ])

    begin
      translator = DeepL::Translator.new(auth_key: "test-key", server_url: "http://127.0.0.1:1")
      expect_raises(DeepL::RequestError) do
        translator.download_translation_memory_export("#{asset_server.url}/download", output_path)
      end
      File.read(output_path).should eq("existing export")
    ensure
      asset_server.close
      File.delete?(output_path)
    end
  end
end
