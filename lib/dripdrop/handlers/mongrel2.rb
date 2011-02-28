=begin
Large portion of at least the concepts (and plenty of the code) used here come from m2r

https://github.com/perplexes/m2r

Under the following license
 
Copyright (c) 2009 Pradeep Elankumaran

Permission is hereby granted, free of charge, to any person obtaining
a copy of this software and associated documentation files (the
"Software"), to deal in the Software without restriction, including
without limitation the rights to use, copy, modify, merge, publish,
distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so, subject to
the following conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
=end

class DripDrop
  class Mongrel2Handler < ZMQBaseHandler
    include ZMQWritableHandler
    include ZMQReadableHandler
    attr_accessor :uuid

    def initialize(*args)
      super(*args)
      @connections = []
      self.uuid = @opts[:uuid]
    end

    def add_connection(connection)
      @connections << connection
    end

    def read_connection
      @connections[0]
    end

    def write_connection
      @connections[1]
    end

    def address
      raise "Not applicable for a Mongrel2Handler"
    end

    def on_readable(socket, messages)
      req = Mongrel2Request.parse_request(messages[0])
      @recv_cbak.call(req)
    end

    def send_resp(uuid, conn_id, msg)
      header = "%s %d:%s," % [uuid, conn_id.size, conn_id]
      string = header + ' ' + msg
      send_message(string)
    end

    def reply(req, msg)
      self.send_resp(req.sender, req.conn_id, msg)
    end

    def reply_http(req, body, code=200, headers={})
      self.reply(req, http_response(body, code, headers))
    end

    def http_response(body, code, headers)
      headers['Content-Length'] = body.size
      headers_s                 = headers.map { |k, v| "%s: %s" % [k, v] }.join("\r\n")

      "HTTP/1.1 #{code} #{StatusMessage[code.to_i]}\r\n#{headers_s}\r\n\r\n#{body}"
    end

    # From WEBrick
    StatusMessage = {
        100 => 'Continue',
        101 => 'Switching Protocols',
        200 => 'OK',
        201 => 'Created',
        202 => 'Accepted',
        203 => 'Non-Authoritative Information',
        204 => 'No Content',
        205 => 'Reset Content',
        206 => 'Partial Content',
        300 => 'Multiple Choices',
        301 => 'Moved Permanently',
        302 => 'Found',
        303 => 'See Other',
        304 => 'Not Modified',
        305 => 'Use Proxy',
        307 => 'Temporary Redirect',
        400 => 'Bad Request',
        401 => 'Unauthorized',
        402 => 'Payment Required',
        403 => 'Forbidden',
        404 => 'Not Found',
        405 => 'Method Not Allowed',
        406 => 'Not Acceptable',
        407 => 'Proxy Authentication Required',
        408 => 'Request Timeout',
        409 => 'Conflict',
        410 => 'Gone',
        411 => 'Length Required',
        412 => 'Precondition Failed',
        413 => 'Request Entity Too Large',
        414 => 'Request-URI Too Large',
        415 => 'Unsupported Media Type',
        416 => 'Request Range Not Satisfiable',
        417 => 'Expectation Failed',
        500 => 'Internal Server Error',
        501 => 'Not Implemented',
        502 => 'Bad Gateway',
        503 => 'Service Unavailable',
        504 => 'Gateway Timeout',
        505 => 'HTTP Version Not Supported'
    }
  end
end

class Mongrel2Request
  attr_reader :sender, :conn_id, :path, :headers, :body

  def initialize(sender, conn_id, path, headers, body)
    @sender  = sender
    @conn_id = conn_id
    @path    = path
    @headers = headers
    @body    = body

    if headers['METHOD'] == 'JSON'
      @data = JSON.parse(@body)
    else
      @data = {}
    end
  end

  def self.parse_netstring(ns)
    len, rest = ns.split(':', 2)
    len = len.to_i
    raise "Netstring did not end in ','" unless rest[len].chr == ','
    [rest[0...len], rest[(len+1)..-1]]
  end

  def self.parse_request(msg)
    sender, conn_id, path, rest = msg.copy_out_string.split(' ', 4)
    headers, head_rest = parse_netstring(rest)
    body, _ = parse_netstring(head_rest)

    headers = JSON.parse(headers)

    self.new(sender, conn_id, path, headers, body)
  end
end