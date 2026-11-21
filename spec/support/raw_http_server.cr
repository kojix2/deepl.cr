require "http"
require "socket"

# Allows deliberately incomplete and slow HTTP responses in transport specs.
class RawHTTPServer
  getter url : String
  getter requests = 0
  @sockets = [] of TCPSocket

  def initialize(&handler : TCPSocket ->)
    @listener = TCPServer.new("127.0.0.1", 0)
    port = @listener.local_address.as(Socket::IPAddress).port
    @url = "http://127.0.0.1:#{port}"
    spawn do
      while socket = @listener.accept?
        @sockets << socket
        spawn handle(socket, handler)
      end
    rescue IO::Error
      # Closing the listener stops acceptance.
    end
  end

  private def handle(socket : TCPSocket, handler) : Nil
    request = HTTP::Request.from_io(socket)
    if request.is_a?(HTTP::Request)
      request.body.try &.gets_to_end
      @requests += 1
      handler.call(socket)
    end
  rescue IO::Error
    # Expected when the client deadline or test cleanup closes a connection.
  ensure
    socket.close unless socket.closed?
  end

  def close : Nil
    @listener.close
    @sockets.each { |socket| socket.close unless socket.closed? }
  end
end
