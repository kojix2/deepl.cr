require "json"

module DeepL
  class TranslationMemory
    include JSON::Serializable

    property translation_memory_id : String
    property name : String
    property source_language : String
    property target_languages : Array(String)
    property segment_count : Int64
    property creation_time : Time?
    property updated_time : Time?

    def initialize(
      @translation_memory_id,
      @name,
      @source_language,
      @target_languages,
      @segment_count,
      @creation_time = nil,
      @updated_time = nil,
    )
    end
  end

  class TranslationMemoryList
    include JSON::Serializable

    property translation_memories : Array(TranslationMemory)
    property total_count : Int32?

    def initialize(@translation_memories, @total_count = nil)
    end
  end

  class TranslationMemoryTargetSegment
    include JSON::Serializable

    property target_segment_id : String
    property target_language : String
    property target_text : String
    property creation_time : Time?
    property updated_time : Time?
    property last_used_time : Time?

    def initialize(
      @target_segment_id,
      @target_language,
      @target_text,
      @creation_time = nil,
      @updated_time = nil,
      @last_used_time = nil,
    )
    end
  end

  class TranslationMemorySegment
    include JSON::Serializable

    property source_segment_id : String
    property source_text : String
    property targets : Array(TranslationMemoryTargetSegment)
    property creation_time : Time?
    property updated_time : Time?
    property last_used_time : Time?

    def initialize(
      @source_segment_id,
      @source_text,
      @targets,
      @creation_time = nil,
      @updated_time = nil,
      @last_used_time = nil,
    )
    end
  end

  class TranslationMemorySegmentList
    include JSON::Serializable

    property segments : Array(TranslationMemorySegment)
    property segment_count : Int64
    property next_page_cursor : String?

    def initialize(@segments, @segment_count, @next_page_cursor = nil)
    end
  end

  class TranslationMemoryImport
    include JSON::Serializable

    property job_id : String
    property upload_url : String
    property expires_at : Time

    def initialize(@job_id, @upload_url, @expires_at)
    end
  end

  class TranslationMemoryJobSourceFile
    include JSON::Serializable

    property content_type : String?
    property content_length : Int64?

    def initialize(@content_type = nil, @content_length = nil)
    end
  end

  class TranslationMemoryJobParameters
    include JSON::Serializable

    property translation_memory_id : String?
    property display_name : String?

    def initialize(@translation_memory_id = nil, @display_name = nil)
    end
  end

  class TranslationMemoryExport
    include JSON::Serializable

    property job_id : String
    property parameters : TranslationMemoryJobParameters

    def initialize(@job_id, @parameters)
    end
  end

  class TranslationMemoryJobStatusMetadata
    include JSON::Serializable

    property required_action : String?

    def initialize(@required_action = nil)
    end
  end

  class TranslationMemoryJobFailure
    include JSON::Serializable

    property message : String?

    def initialize(@message = nil)
    end
  end

  class TranslationMemoryJobResult
    include JSON::Serializable

    property status : String
    property status_metadata : TranslationMemoryJobStatusMetadata?
    property download_url : String?
    property expires_at : Time?
    property error : TranslationMemoryJobFailure?
    property translation_memory_id : String?
    property skipped_segment_count : Int64?

    def initialize(
      @status,
      @status_metadata = nil,
      @download_url = nil,
      @expires_at = nil,
      @error = nil,
      @translation_memory_id = nil,
      @skipped_segment_count = nil,
    )
    end
  end

  class TranslationMemoryJob
    include JSON::Serializable

    property job_id : String
    property product : String
    property operation : String
    property creation_time : Time
    property updated_time : Time
    property source_file : TranslationMemoryJobSourceFile?
    property parameters : TranslationMemoryJobParameters
    property results : Array(TranslationMemoryJobResult)

    def initialize(
      @job_id,
      @product,
      @operation,
      @creation_time,
      @updated_time,
      @parameters,
      @results,
      @source_file = nil,
    )
    end
  end

  class TranslationMemoryJobError < DeepLError
    property job : TranslationMemoryJob?

    def initialize(@job : TranslationMemoryJob? = nil, message : String? = nil)
      super(message || "Translation memory job failed.")
    end
  end

  class Translator
    def list_translation_memories(
      page : Int32? = nil,
      page_size : Int32? = nil,
    ) : TranslationMemoryList
      url = api_url("/v3/translation_memories")
      params = {
        "page"      => page,
        "page_size" => page_size,
      }.compact!

      response = with_transport_error do
        Crest.get(
          url,
          params: params,
          headers: http_headers_base,
          handle_errors: false,
          max_redirects: 0,
        )
      end
      handle_response(response)
      TranslationMemoryList.from_json(response.body)
    end

    def get_translation_memory(translation_memory_id : String) : TranslationMemory
      url = api_url("/v3/translation_memories/#{translation_memory_id}")
      response = with_transport_error do
        Crest.get(
          url,
          headers: http_headers_base,
          handle_errors: false,
          max_redirects: 0,
        )
      end
      handle_response(response)
      TranslationMemory.from_json(response.body)
    end

    def create_translation_memory_import(
      file_name : String,
      content_length : Int,
      content_type : String = "application/xml",
      display_name : String? = nil,
    ) : TranslationMemoryImport
      validate_translation_memory_import(file_name, content_length, content_type)

      body = JSON.build do |json|
        json.object do
          json.field "source_file" do
            json.object do
              json.field "file_name", file_name
              json.field "content_type", content_type
              json.field "content_length", content_length
            end
          end
          if display_name
            json.field "parameters" do
              json.object do
                json.field "display_name", display_name
              end
            end
          end
        end
      end

      response = with_transport_error do
        Crest.post(
          api_url("/v3/translation_memories/import"),
          body,
          json: true,
          headers: http_headers_json,
          handle_errors: false,
          max_redirects: 0,
        )
      end
      handle_response(response)
      TranslationMemoryImport.from_json(response.body)
    end

    def upload_translation_memory_import(
      import_job : TranslationMemoryImport,
      path : Path | String,
      content_type : String = "application/xml",
    ) : Nil
      upload_translation_memory_import(import_job.upload_url, path, content_type)
    end

    def upload_translation_memory_import(
      upload_url : String,
      path : Path | String,
      content_type : String = "application/xml",
    ) : Nil
      source_path = Path[path]
      headers = {
        "Content-Type"   => content_type,
        "Content-Length" => File.info(source_path).size.to_s,
      }
      File.open(source_path, "rb") do |file|
        response = with_transport_error do
          Crest.put(
            upload_url,
            file,
            headers: headers,
            handle_errors: false,
            max_redirects: 0,
          )
        end
        handle_response(response)
      end
    end

    def get_translation_memory_job(job_id : String) : TranslationMemoryJob
      response = translation_memory_job_response(job_id)
      handle_response(response)
      TranslationMemoryJob.from_json(response.body)
    end

    def create_translation_memory_export(
      translation_memory_id : String,
    ) : TranslationMemoryExport
      response = with_transport_error do
        Crest.post(
          api_url("/v3/translation_memories/#{translation_memory_id}/export"),
          headers: http_headers_json,
          handle_errors: false,
          max_redirects: 0,
        )
      end
      handle_response(response)
      TranslationMemoryExport.from_json(response.body)
    end

    def download_translation_memory_export(
      download_url : String,
      output_file : Path | String,
    ) : Nil
      with_transport_error do
        Crest.get(
          download_url,
          headers: {} of String => String,
          handle_errors: false,
          max_redirects: 0,
        ) do |response|
          handle_response(response)
          write_translation_memory_export(response.body_io, output_file)
        end
      end
    end

    def delete_translation_memory(translation_memory_id : String) : Bool
      response = with_transport_error do
        Crest.delete(
          api_url("/v3/translation_memories/#{translation_memory_id}"),
          headers: http_headers_base,
          handle_errors: false,
          max_redirects: 0,
        )
      end
      handle_response(response)
      true
    end

    def list_translation_memory_segments(
      translation_memory_id : String,
      page_size : Int32? = nil,
      page_cursor : String? = nil,
      filter_text : String? = nil,
      filter_case_sensitive : Bool? = nil,
    ) : TranslationMemorySegmentList
      url = api_url("/v3/translation_memories/#{translation_memory_id}/segments")
      params = {
        "page_size"             => page_size,
        "page_cursor"           => page_cursor,
        "filter_text"           => filter_text,
        "filter_case_sensitive" => filter_case_sensitive,
      }.compact!

      response = with_transport_error do
        Crest.get(
          url,
          params: params,
          headers: http_headers_base,
          handle_errors: false,
          max_redirects: 0,
        )
      end
      handle_response(response)
      TranslationMemorySegmentList.from_json(response.body)
    end

    def wait_for_translation_memory_job(
      job_id : String,
      interval = 5.0,
      timeout : Time::Span? = nil,
      &block : (TranslationMemoryJob ->)
    ) : TranslationMemoryJob
      wait_for_translation_memory_job(
        job_id,
        interval,
        timeout: timeout,
        block: block,
      )
    end

    def wait_for_translation_memory_job(
      job_id : String,
      interval = 5.0,
      timeout : Time::Span? = nil,
      block : (TranslationMemoryJob ->)? = nil,
    ) : TranslationMemoryJob
      validate_translation_memory_polling_options(interval, timeout)
      deadline = timeout.try { |value| Time.instant + value }
      first_poll = true
      last_job : TranslationMemoryJob? = nil

      loop do
        unless first_poll
          sleep_for_translation_memory_job_poll(interval, deadline, last_job)
        end
        first_poll = false

        raise_translation_memory_job_timeout(deadline, last_job)
        job = get_translation_memory_job_with_retry(job_id, interval, deadline, last_job)
        last_job = job
        raise_translation_memory_job_timeout(deadline, last_job)
        block.try &.call(job)

        result = translation_memory_job_result(job)
        case result.status
        when "completed"
          return job
        when "failed", "expired"
          message = result.error.try(&.message) || "Translation memory job #{result.status}."
          raise TranslationMemoryJobError.new(job, message)
        end
      end
    end

    def import_translation_memory(
      path : Path | String,
      display_name : String? = nil,
      content_type : String = "application/xml",
      interval = 5.0,
      timeout : Time::Span? = nil,
    ) : TranslationMemoryJob
      source_path = Path[path]
      import_job = create_translation_memory_import(
        source_path.basename.to_s,
        File.info(source_path).size,
        content_type,
        display_name,
      )
      upload_translation_memory_import(import_job, source_path, content_type)
      wait_for_translation_memory_job(import_job.job_id, interval, timeout: timeout)
    end

    def export_translation_memory(
      translation_memory_id : String,
      output_file : Path | String,
      interval = 5.0,
      timeout : Time::Span? = nil,
    ) : TranslationMemoryJob
      export_job = create_translation_memory_export(translation_memory_id)
      job = wait_for_translation_memory_job(export_job.job_id, interval, timeout: timeout)
      result = translation_memory_job_result(job)
      download_url = result.download_url || raise TranslationMemoryJobError.new(
        job,
        "Completed translation memory export did not include a download URL.",
      )
      download_translation_memory_export(download_url, output_file)
      job
    end

    private def translation_memory_job_response(job_id : String) : Crest::Response
      with_transport_error do
        Crest.get(
          api_url("/v3/translation_memories/jobs/#{job_id}"),
          headers: http_headers_base,
          handle_errors: false,
          max_redirects: 0,
        )
      end
    end

    private def get_translation_memory_job_with_retry(
      job_id : String,
      interval,
      deadline : Time::Instant?,
      last_job : TranslationMemoryJob?,
    ) : TranslationMemoryJob
      retries = 0

      loop do
        response = begin
          translation_memory_job_response(job_id)
        rescue error : RequestError
          raise error unless retries < 2

          retries += 1
          sleep_for_translation_memory_job_poll(interval, deadline, last_job)
          next
        end

        if transient_translation_memory_job_response?(response)
          handle_response(response) unless retries < 2

          retries += 1
          sleep_for_translation_memory_job_poll(interval, deadline, last_job)
          next
        end

        handle_response(response)
        return TranslationMemoryJob.from_json(response.body)
      end
    end

    private def transient_translation_memory_job_response?(response : Crest::Response) : Bool
      {
        HTTP::Status::TOO_MANY_REQUESTS.to_i,
        HTTP::Status::SERVICE_UNAVAILABLE.to_i,
        HTTP_STATUS_TOO_MANY_REQUESTS,
      }.includes?(response.status_code.to_i)
    end

    private def translation_memory_job_result(job : TranslationMemoryJob) : TranslationMemoryJobResult
      job.results.first? || raise TranslationMemoryJobError.new(
        job,
        "Translation memory job did not include a result.",
      )
    end

    private def validate_translation_memory_import(
      file_name : String,
      content_length : Int,
      content_type : String,
    ) : Nil
      raise ArgumentError.new("file_name must not be empty.") if file_name.empty?
      raise ArgumentError.new("file_name must not exceed 100 characters.") if file_name.size > 100
      raise ArgumentError.new("content_type must not exceed 127 characters.") if content_type.size > 127
      raise ArgumentError.new("content_length must be greater than zero.") unless content_length > 0
    end

    private def validate_translation_memory_polling_options(
      interval,
      timeout : Time::Span?,
    ) : Nil
      raise ArgumentError.new("Translation memory job polling interval must be positive.") unless interval > 0
      if timeout && timeout < Time::Span.zero
        raise ArgumentError.new("Translation memory job polling timeout must not be negative.")
      end
    end

    private def sleep_for_translation_memory_job_poll(
      interval,
      deadline : Time::Instant?,
      last_job : TranslationMemoryJob?,
    ) : Nil
      interval_span = Time::Span.new(nanoseconds: (interval * 1_000_000_000).to_i64)
      sleep_span = interval_span

      if deadline
        remaining = deadline - Time.instant
        raise_translation_memory_job_timeout(deadline, last_job) if remaining <= Time::Span.zero
        sleep_span = remaining if remaining < sleep_span
      end

      sleep sleep_span
      raise_translation_memory_job_timeout(deadline, last_job)
    end

    private def raise_translation_memory_job_timeout(
      deadline : Time::Instant?,
      last_job : TranslationMemoryJob?,
    ) : Nil
      return unless deadline && Time.instant >= deadline

      raise TranslationMemoryJobError.new(last_job, "Translation memory job timed out.")
    end

    private def write_translation_memory_export(body : IO, output_file : Path | String) : Nil
      output_path = Path[output_file]
      temporary_file = File.tempfile("deepl-translation-memory", ".tmp", dir: output_path.parent.to_s)
      temporary_path = temporary_file.path
      temporary_file.close

      begin
        File.open(temporary_path, "wb") do |file|
          IO.copy(body, file)
        end
        File.rename(temporary_path, output_path)
      ensure
        temporary_file.close unless temporary_file.closed?
        File.delete?(temporary_path)
      end
    end
  end
end
