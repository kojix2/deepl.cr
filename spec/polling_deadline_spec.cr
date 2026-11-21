require "./spec_helper"
require "./support/raw_http_server"

describe "polling HTTP deadlines" do
  it "closes an active connection when the polling deadline expires" do
    disconnected = Channel(Nil).new(1)
    server = RawHTTPServer.new do |socket|
      disconnected.send(nil) if socket.read_byte.nil?
    end
    begin
      expect_raises(DeepL::DocumentTranslationError, /timed out/) do
        DeepL::Translator.new("test-key", nil, server.url).translate_document_wait_until_done(
          DeepL::DocumentHandle.new("id", "key"), timeout: 80.milliseconds)
      end
      select
      when disconnected.receive
        # The server observed EOF, rather than merely the caller returning.
      when timeout(500.milliseconds)
        fail "Polling timeout did not close the active HTTP connection"
      end
    ensure
      server.close
    end
  end

  it "retains the last translation-memory job when a later HTTP request times out" do
    processing = %({"job_id":"job-id","product":"translation_memory","operation":"export","creation_time":"2026-08-06T15:04:25Z","updated_time":"2026-08-06T15:04:25Z","parameters":{},"results":[{"status":"processing"}]})
    calls = 0
    server = RawHTTPServer.new do |socket|
      calls += 1
      if calls == 1
        socket << "HTTP/1.1 200 OK\r\nContent-Length: #{processing.bytesize}\r\n\r\n#{processing}"
        socket.flush
      else
        socket.read_byte
      end
    end
    begin
      error = expect_raises(DeepL::TranslationMemoryJobError, /timed out/) do
        DeepL::Translator.new("test-key", nil, server.url)
          .wait_for_translation_memory_job("job-id", interval: 0.001, timeout: 80.milliseconds)
      end
      error.job.try(&.job_id).should eq("job-id")
      server.requests.should eq(2)
    ensure
      server.close
    end
  end

  [:document, :translation_memory].each do |endpoint|
    [:unresponsive, :delayed_headers, :trickling_body].each do |behavior|
      it "bounds #{endpoint} polling with #{behavior}" do
        server = RawHTTPServer.new do |socket|
          case behavior
          when :unresponsive
            sleep 1.second
          when :delayed_headers
            sleep 1.second
            socket << "HTTP/1.1 200 OK\r\nContent-Length: 2\r\n\r\n{}"
          when :trickling_body
            socket << "HTTP/1.1 200 OK\r\nContent-Length: 1000\r\n\r\n"
            100.times do
              socket << " "
              socket.flush
              sleep 10.milliseconds
            end
          end
        end
        begin
          translator = DeepL::Translator.new("test-key", nil, server.url)
          started_at = Time.instant
          if endpoint == :document
            expect_raises(DeepL::DocumentTranslationError, /timed out/) do
              translator.translate_document_wait_until_done(
                DeepL::DocumentHandle.new("id", "key"),
                interval: 0.001,
                timeout: 80.milliseconds,
              )
            end
          else
            error = expect_raises(DeepL::TranslationMemoryJobError, /timed out/) do
              translator.wait_for_translation_memory_job("id", interval: 0.001, timeout: 80.milliseconds)
            end
            error.job.should be_nil
          end
          started_at.elapsed.should be < 750.milliseconds
          server.requests.should eq(1)
        ensure
          server.close
        end
      end
    end
  end
end
