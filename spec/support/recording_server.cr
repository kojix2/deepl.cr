require "http/server"

# A deliberately small local HTTP server for asserting the requests a spec sends.
class RecordingServer
  record ScriptedResponse,
    status_code : Int32,
    body : String = "",
    headers : Hash(String, String) = {} of String => String

  record ReceivedRequest, method : String, resource : String, body : String

  getter requests : Array(ReceivedRequest)
  getter url : String

  def initialize(@responses : Array(ScriptedResponse))
    @requests = [] of ReceivedRequest
    @server = HTTP::Server.new do |context|
      body = context.request.body.try(&.gets_to_end) || ""
      @requests << ReceivedRequest.new(context.request.method, context.request.resource, body)

      scripted_response = @responses.shift? || ScriptedResponse.new(500, "No scripted response")
      context.response.status_code = scripted_response.status_code
      scripted_response.headers.each do |name, value|
        context.response.headers[name] = value
      end
      context.response.content_length = scripted_response.body.bytesize
      context.response.print(scripted_response.body) unless scripted_response.body.empty?
      context.response.close
    end

    address = @server.bind_tcp("127.0.0.1", 0)
    @url = "http://127.0.0.1:#{address.port}"
    spawn { @server.listen }
  end

  def close : Nil
    @server.close unless @server.closed?
  end
end
