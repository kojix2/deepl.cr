module DeepL
  class Translator
    def translate_document(
      path,
      target_lang,
      source_lang = nil,
      formality = nil,
      glossary_id = nil,
      glossary_name = nil, # original option of deepl.cr
      output_format = nil,
      output_file = nil,
      interval = 5.0,
      message_prefix = "[deepl.cr] ",
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
        interval: interval,
        message_prefix: message_prefix,
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
      interval = 5.0,
      message_prefix = "[deepl.cr] ",
      block : (String ->)? = nil,
    )
      source_path = Path[path]

      document_handle = translate_document_upload(
        path: source_path,
        target_lang: target_lang,
        source_lang: source_lang,
        formality: formality,
        glossary_id: glossary_id,
        glossary_name: glossary_name,
        output_format: output_format
      )

      prefix = message_prefix
      block.try &.call("#{prefix}Document uploaded")
      block.try &.call("#{prefix}File: #{source_path}")
      block.try &.call("#{prefix}ID: #{document_handle.id}")
      block.try &.call("#{prefix}Key: #{document_handle.key}")

      translate_document_wait_until_done(document_handle, interval) do |document_status|
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
      output_file = output_file.parent / (output_base_name + output_extension)
    end

    def translate_document_upload(
      path : Path | String,
      target_lang,
      source_lang = nil,
      formality = nil,
      glossary_id = nil,
      glossary_name = nil, # original option of deepl.cr
      output_format = nil,
    ) : DocumentHandle
      path = Path[path] if path.is_a?(String)
      if glossary_name
        glossary_id ||= find_glossary_info_by_name(glossary_name).glossary_id
      end
      params = {
        "source_lang"   => source_lang,
        "formality"     => formality,
        "target_lang"   => target_lang,
        "glossary_id"   => glossary_id,
        "output_format" => output_format,
      }.compact!
      file = File.open(path)
      params = params.merge({"file" => file})

      response = Crest.post(api_url_document, form: params, headers: http_headers_base)
      handle_response(response)

      DocumentHandle.from_json(response.body)
    end

    def translate_document_wait_until_done(
      handle : DocumentHandle,
      interval = 5.0,
      &block : (DocumentStatus ->)
    )
      translate_document_wait_until_done(
        handle: handle,
        interval: interval,
        block: block
      )
    end

    def translate_document_wait_until_done(
      handle : DocumentHandle,
      interval = 5.0,
      block : (DocumentStatus ->)? = nil,
    )
      loop do
        sleep_interval_ns = (interval * 1_000_000_000).to_i64
        sleep Time::Span.new(nanoseconds: sleep_interval_ns)

        document_status = translate_document_get_status(handle)

        block.try &.call(document_status)

        case document_status.status
        when "done"  then break
        when "error" then raise DocumentTranslationError.new(document_status.error_message)
        end
      end
    end

    def translate_document_get_status(handle : DocumentHandle) : DocumentStatus
      url = "#{api_url_document}/#{handle.id}"
      data = {"document_key" => handle.key}
      response = Crest.post(url, form: data, headers: http_headers_json)
      handle_response(response)
      DocumentStatus.from_json(response.body)
    end

    def translate_document_download(handle : DocumentHandle, output_file)
      data = {"document_key" => handle.key}
      url = "#{api_url_document}/#{handle.id}/result"
      Crest.post(url, form: data, headers: http_headers_json) do |response|
        raise DocumentTranslationError.new unless response.success?
        File.open(output_file, "wb") do |file|
          IO.copy(response.body_io, file)
        end
      end
    end
  end
end
