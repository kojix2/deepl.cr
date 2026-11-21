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
      enable_watermark : Bool? = nil,
      *,
      on_uploaded : (DocumentHandle ->)? = nil,
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
        enable_watermark: enable_watermark,
        on_uploaded: on_uploaded,
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
      enable_watermark : Bool? = nil,
      *,
      on_uploaded : (DocumentHandle ->)? = nil,
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
        enable_watermark: enable_watermark,
      )

      on_uploaded.try &.call(document_handle)

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

      if output_file
        block.try &.call("#{prefix}Downloading translated document to #{output_file}")
        translate_document_download(document_handle, output_file)
      else
        output_file = generate_output_file(source_path, target_lang, output_format)
        block.try &.call("#{prefix}Downloading translated document")
        output_file = download_document_to_unique_file(document_handle, output_file)
      end

      block.try &.call("#{prefix}Document saved as #{output_file}")
    end

    private def generate_output_file(source_path : Path, target_lang, output_format) : Path
      output_base_name = "#{source_path.stem}_#{target_lang}"
      output_extension = output_format ? ".#{output_format.downcase}" : source_path.extension
      source_path.parent / (output_base_name + output_extension)
    end

    private def download_document_to_unique_file(handle : DocumentHandle, output_file : Path) : Path
      temporary_file = File.tempfile("deepl-document-output", ".tmp", dir: output_file.parent.to_s)
      temporary_path = temporary_file.path
      temporary_file.close
      downloaded = false
      begin
        translate_document_download(handle, temporary_path)
        downloaded = true
        timestamp = Time.utc.to_unix
        suffix = 0
        loop do
          candidate = if suffix == 0
                        output_file
                      else
                        extra = suffix == 1 ? "" : "_#{suffix - 1}"
                        output_file.parent / "#{output_file.stem}_#{timestamp}#{extra}#{output_file.extension}"
                      end
          begin
            File.link(temporary_path, candidate)
            File.delete(temporary_path)
            return candidate
          rescue File::AlreadyExistsError
            suffix += 1
          end
        end
      rescue error
        raise DocumentDownloadError.new(temporary_path, error) if downloaded
        raise error
      ensure
        File.delete?(temporary_path) unless downloaded
      end
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
      enable_watermark : Bool? = nil,
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
        "enable_watermark"             => enable_watermark,
      }.compact!
      File.open(path) do |file|
        params = params.merge({"file" => file})

        request = Crest::Request.new(
          :post,
          api_url_document,
          form: params,
          stream_multipart: true,
          headers: http_headers_base,
          handle_errors: false,
          max_redirects: 0
        )
        begin
          response = with_transport_error { request.execute }
          handle_response(response)
          DocumentHandle.from_json(response.body)
        ensure
          if body = request.form_data.as?(IO)
            # Finish Crest's multipart producer before closing its source file,
            # including when the server rejects or disconnects during upload.
            begin
              body.skip_to_end
            ensure
              body.close
            end
          end
        end
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
      output_path = Path[output_file]
      raise ArgumentError.new("Document output path is a directory: #{output_path}") if Dir.exists?(output_path)
      temporary_file = File.tempfile("deepl-document", ".tmp", dir: output_path.parent.to_s)
      temporary_path = temporary_file.path
      receiving = false
      preserved = false
      begin
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
            receiving = true
            received_bytes = IO.copy(response.body_io, temporary_file)
            if content_length = response.http_client_res.headers["Content-Length"]?
              expected_bytes = content_length.to_i64
              if received_bytes != expected_bytes
                raise IO::EOFError.new("Incomplete document download: expected #{expected_bytes} bytes, received #{received_bytes}.")
              end
            end
            temporary_file.close
            finalize_document_result(temporary_path, output_path)
          end
        end
      rescue error
        if receiving
          preserved = true
          raise DocumentDownloadError.new(temporary_path, error)
        end
        raise error
      ensure
        # A second close error must not hide the exception with the recovery path.
        begin
          temporary_file.close unless temporary_file.closed?
        rescue error
          raise error unless preserved
        ensure
          File.delete?(temporary_path) unless preserved
        end
      end
    end

    private def document_status_response(handle : DocumentHandle, deadline : Time::Instant? = nil) : Crest::Response
      url = "#{api_url_document}/#{handle.id}"
      data = {"document_key" => handle.key}
      with_transport_error do
        request = Crest::Request.new(
          :post,
          url,
          form: data,
          headers: http_headers_json,
          json: true,
          handle_errors: false,
          max_redirects: 0
        )
        execute_polling_request(request, deadline)
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
          document_status_response(handle, deadline)
        rescue PollingTimeoutError
          raise DocumentTranslationError.new("Document translation timed out.")
        rescue error : RequestError
          raise_document_polling_timeout(deadline)
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
      raise ArgumentError.new("Document polling interval must be finite.") unless interval.to_f.finite?
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

    private def finalize_document_result(temporary_path : String, output_path : Path) : Nil
      File.rename(temporary_path, output_path)
    end
  end
end
