require "./document_handle"
require "./document_status"

module DeepL
  class Translator
    def translate_document(
      path,
      target_lang,
      source_lang = nil,
      formality = nil,
      glossary_id = nil,
      glossary_name = nil,
      output_format = nil,
      output_file = nil,
      filename = nil,
      interval = 5.0,
      message_prefix = "[deepl.cr] ",
      timeout : Time::Span? = nil,
      glossary_ids : Array(String)? = nil,
      style_id = nil,
      translation_memory_id = nil,
      translation_memory_threshold : Int32? = nil,
      &block : (String ->)
    )
      translate_document(
        path: path,
        target_lang: target_lang,
        source_lang: source_lang,
        formality: formality,
        glossary_id: glossary_id,
        glossary_name: glossary_name,
        output_format: output_format,
        output_file: output_file,
        filename: filename,
        interval: interval,
        message_prefix: message_prefix,
        timeout: timeout,
        glossary_ids: glossary_ids,
        style_id: style_id,
        translation_memory_id: translation_memory_id,
        translation_memory_threshold: translation_memory_threshold,
        block: block
      )
    end

    def translate_document(
      path,
      target_lang,
      source_lang = nil,
      formality = nil,
      glossary_id = nil,
      glossary_name = nil,
      output_format = nil,
      output_file = nil,
      filename = nil,
      interval = 5.0,
      message_prefix = "[deepl.cr] ",
      timeout : Time::Span? = nil,
      block : (String ->)? = nil,
      glossary_ids : Array(String)? = nil,
      style_id = nil,
      translation_memory_id = nil,
      translation_memory_threshold : Int32? = nil,
    )
      validate_document_polling_options(interval, timeout)
      source_path = Path[path]

      document_handle = translate_document_upload(
        path: source_path,
        target_lang: target_lang,
        source_lang: source_lang,
        formality: formality,
        glossary_id: glossary_id,
        glossary_name: glossary_name,
        glossary_ids: glossary_ids,
        output_format: output_format,
        filename: filename,
        style_id: style_id,
        translation_memory_id: translation_memory_id,
        translation_memory_threshold: translation_memory_threshold,
      )

      prefix = message_prefix
      block.try &.call("#{prefix}Document uploaded")
      block.try &.call("#{prefix}File: #{source_path}")
      block.try &.call("#{prefix}ID: #{document_handle.id}")

      translate_document_wait_until_done(document_handle, interval, timeout: timeout) do |document_status|
        block.try &.call("#{prefix}Status: #{document_status.status}")
        block.try &.call("#{prefix}Seconds Remaining: #{document_status.seconds_remaining}") if document_status.seconds_remaining
        block.try &.call("#{prefix}Billed Characters: #{document_status.billed_characters}") if document_status.billed_characters
        block.try &.call("#{prefix}Error Message: #{document_status.error_message}") if document_status.error_message
      end

      output_file ||= generate_output_file(source_path, target_lang, output_format)

      block.try &.call("#{prefix}Downloading translated document to #{output_file}")
      translate_document_download(document_handle, output_file)

      block.try &.call("#{prefix}Document saved as #{output_file}")
    end

    private def generate_output_file(source_path : Path, target_lang, output_format) : Path
      output_base_name = "#{source_path.stem}_#{target_lang}"
      output_extension = output_format ? ".#{output_format.downcase}" : source_path.extension
      output_file = source_path.parent / (output_base_name + output_extension)
      ensure_unique_output_file(output_file)
    end

    private def ensure_unique_output_file(output_file : Path) : Path
      return output_file unless File.exists?(output_file)
      output_base_name = "#{output_file.stem}_#{Time.utc.to_unix}"
      output_extension = output_file.extension
      output_file.parent / (output_base_name + output_extension)
    end

    def translate_document_upload(
      path : Path | String,
      target_lang,
      source_lang = nil,
      formality = nil,
      glossary_id = nil,
      glossary_name = nil,
      output_format = nil,
      filename = nil,
      glossary_ids : Array(String)? = nil,
      style_id = nil,
      translation_memory_id = nil,
      translation_memory_threshold : Int32? = nil,
    ) : DocumentHandle
      validate_glossary_ids(glossary_ids, source_lang, glossary_id, glossary_name)

      path = Path[path] if path.is_a?(String)
      if glossary_name
        glossary_id ||= find_multilingual_glossary_by_name(glossary_name).glossary_id
      end
      params = {
        "source_lang"                  => source_lang,
        "formality"                    => formality,
        "target_lang"                  => target_lang,
        "glossary_id"                  => glossary_id,
        "glossary_ids"                 => glossary_ids.try(&.join(",")),
        "output_format"                => output_format,
        "filename"                     => filename,
        "style_id"                     => style_id,
        "translation_memory_id"        => translation_memory_id,
        "translation_memory_threshold" => translation_memory_threshold,
      }.compact!
      File.open(path) do |file|
        params = params.merge({"file" => file})

        response = with_transport_error do
          Crest.post(
            api_url_document,
            form: params,
            headers: http_headers_base,
            handle_errors: false,
            max_redirects: 0
          )
        end
        handle_response(response)

        DocumentHandle.from_json(response.body)
      end
    end

    def translate_document_wait_until_done(
      handle : DocumentHandle,
      interval = 5.0,
      timeout : Time::Span? = nil,
      &block : (DocumentStatus ->)
    )
      translate_document_wait_until_done(
        handle: handle,
        interval: interval,
        timeout: timeout,
        block: block
      )
    end

    def translate_document_wait_until_done(
      handle : DocumentHandle,
      interval = 5.0,
      timeout : Time::Span? = nil,
      block : (DocumentStatus ->)? = nil,
    )
      validate_document_polling_options(interval, timeout)

      deadline = timeout.try { |value| Time.instant + value }
      first_poll = true

      loop do
        unless first_poll
          sleep_for_document_status_poll(interval, deadline)
        end
        first_poll = false

        raise_document_polling_timeout(deadline)
        document_status = translate_document_get_status_with_retry(handle, interval, deadline)
        raise_document_polling_timeout(deadline)

        block.try &.call(document_status)

        case document_status.status
        when "done"  then break
        when "error" then raise DocumentTranslationError.new(document_status.error_message)
        end
      end
    end

    def translate_document_get_status(handle : DocumentHandle) : DocumentStatus
      response = document_status_response(handle)
      handle_response(response)
      DocumentStatus.from_json(response.body)
    end

    def translate_document_download(handle : DocumentHandle, output_file)
      data = {"document_key" => handle.key}
      url = "#{api_url_document}/#{handle.id}/result"
      with_transport_error do
        Crest.post(
          url,
          form: data,
          headers: http_headers_json,
          json: true,
          handle_errors: false,
          max_redirects: 0
        ) do |response|
          handle_response(response)
          write_document_result(response.body_io, output_file)
        end
      end
    end

    private def document_status_response(handle : DocumentHandle) : Crest::Response
      url = "#{api_url_document}/#{handle.id}"
      data = {"document_key" => handle.key}
      with_transport_error do
        Crest.post(
          url,
          form: data,
          headers: http_headers_json,
          json: true,
          handle_errors: false,
          max_redirects: 0
        )
      end
    end

    private def translate_document_get_status_with_retry(
      handle : DocumentHandle,
      interval,
      deadline : Time::Instant?,
    ) : DocumentStatus
      retries = 0

      loop do
        response = begin
          document_status_response(handle)
        rescue error : RequestError
          raise error unless retries < 2

          retries += 1
          sleep_for_document_status_poll(interval, deadline)
          next
        end

        if transient_document_status_response?(response)
          handle_response(response) unless retries < 2

          retries += 1
          sleep_for_document_status_poll(interval, deadline)
          next
        end

        handle_response(response)
        return DocumentStatus.from_json(response.body)
      end
    end

    private def transient_document_status_response?(response : Crest::Response) : Bool
      {
        HTTP::Status::TOO_MANY_REQUESTS.to_i,
        HTTP::Status::SERVICE_UNAVAILABLE.to_i,
        HTTP_STATUS_TOO_MANY_REQUESTS,
      }.includes?(response.status_code.to_i)
    end

    private def validate_document_polling_options(interval, timeout : Time::Span?) : Nil
      raise ArgumentError.new("Document polling interval must be positive.") unless interval > 0
      if timeout && timeout < Time::Span.zero
        raise ArgumentError.new("Document polling timeout must not be negative.")
      end
    end

    private def sleep_for_document_status_poll(interval, deadline : Time::Instant?) : Nil
      interval_span = Time::Span.new(nanoseconds: (interval * 1_000_000_000).to_i64)
      sleep_span = interval_span

      if deadline
        remaining = deadline - Time.instant
        raise_document_polling_timeout(deadline) if remaining <= Time::Span.zero
        sleep_span = remaining if remaining < sleep_span
      end

      sleep sleep_span
      raise_document_polling_timeout(deadline)
    end

    private def raise_document_polling_timeout(deadline : Time::Instant?) : Nil
      return unless deadline && Time.instant >= deadline

      raise DocumentTranslationError.new("Document translation timed out.")
    end

    private def write_document_result(body : IO, output_file) : Nil
      output_path = Path[output_file]
      temporary_file = File.tempfile("deepl-document", ".tmp", dir: output_path.parent.to_s)
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
