require 'spec_helper'

m2_req    = '34f9cfef-dc52-4b7f-b197-098765432112 16 /handlertest 537:{"PATH":"/handlertest","accept-language":"en-us,en;q=0.5","user-agent":"Mozilla/5.0 (X11; U; Linux x86_64; en-US; rv:1.9.2.13) Gecko/20110207 Gentoo Firefox/3.6.13","host":"it.wishdev.org:6767","accept-charset":"ISO-8859-1,utf-8;q=0.7,*;q=0.7","accept":"text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8","keep-alive":"115","x-forwarded-for":"127.0.0.1","cache-control":"max-age=0","connection":"keep-alive","accept-encoding":"gzip,deflate","METHOD":"GET","VERSION":"HTTP/1.1","URI":"/handlertest","PATTERN":"/handlertest"},0:,'
dd_resp   = "34f9cfef-dc52-4b7f-b197-098765432112 2:16, HTTP/1.1 200 OK\r\nContent-Length: 19\r\n\r\nHello from DripDrop"

body      = ""
conn_id   = "16"
headers   = {"PATH"=>"/handlertest",
              "accept-language"=>"en-us,en;q=0.5",
              "user-agent"=>
                "Mozilla/5.0 (X11; U; Linux x86_64; en-US; rv:1.9.2.13) Gecko/20110207 Gentoo Firefox/3.6.13",
              "host"=>"it.wishdev.org:6767",
              "accept-charset"=>"ISO-8859-1,utf-8;q=0.7,*;q=0.7",
              "accept"=>"text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
              "keep-alive"=>"115",
              "x-forwarded-for"=>"127.0.0.1",
              "cache-control"=>"max-age=0",
              "connection"=>"keep-alive",
              "accept-encoding"=>"gzip,deflate",
              "METHOD"=>"GET",
              "VERSION"=>"HTTP/1.1",
              "URI"=>"/handlertest",
              "PATTERN"=>"/handlertest"}
path      = "/handlertest"
sender    = "34f9cfef-dc52-4b7f-b197-098765432112"

describe "zmq m2" do
  def pp_send_messages(to_send)
    responses = []
    requests = []
    
    @node = run_reactor(2) do
      addr = rand_addr
      addr2 = rand_addr
      
      m2_send = zmq_push(addr, :bind, {:msg_format => :raw})
      m2_recv = zmq_subscribe(addr2, :bind, {:msg_format => :raw})
      
      dd = zmq_m2([addr, addr2])

      dd.on_receive do |req|
        requests << req
        dd.reply_http req, "Hello from DripDrop"
      end

      m2_recv.on_receive do |msg|
        responses << msg
      end

      sleep 1
      
      to_send.each {|message| m2_send.send_message(message)}
    end
     
    {:responses => responses, :requests => requests}
  end
  describe "basic sending and receiving" do
    before(:all) do
      @sent = [m2_req]
      pp_info = pp_send_messages(@sent)
      @responses     = pp_info[:responses]
      @requests      = pp_info[:requests]
    end

    it "should parse a request" do
      @requests[0].body.should == body
      @requests[0].conn_id.should == conn_id
      @requests[0].headers.should == headers
      @requests[0].path.should == path
      @requests[0].sender.should == sender
    end

    it "should respond to an http request" do
      @responses[0][0].copy_out_string.should == dd_resp
    end
  end
end
