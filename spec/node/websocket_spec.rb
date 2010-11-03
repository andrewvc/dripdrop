require 'spec_helper'

describe "websockets" do
  def websockets_send_messages(to_send,&block)
    received  = []
    responses = []
    server = nil
    
    @node = run_reactor(2) do
      addr = rand_addr('ws')
      
      server = websocket(addr)
      server.on_open do |conn|
      end.on_recv do |message,conn|
        received << message
        conn.send_message(message)
      end.on_close do |conn|
      end.on_error do |conn|
      end
      
      EM.defer do
        client = WebSocket.new(addr)
        to_send.each do |message|
          client.send(message.json_encoded)
        end
        while message = client.receive
          responses << DripDrop::Message.decode_json(message)
        end
      end
      
      zmq_subscribe(rand_addr, :bind) {} #Keep zmqmachine happy
    end
    
    {:received => received, :responses => responses, :handlers => {:server => server }}
  end
  describe "basic sending and receiving" do
    before(:all) do
      @sent = []
      10.times {|i| @sent << DripDrop::Message.new("test-#{i}")}
      ws_info = websockets_send_messages(@sent)
      @received  = ws_info[:received]
      @responses = ws_info[:responses]
    end

    it "should receive all sent messages" do
      recvd_names = @received.map(&:name).inject(Set.new) {|memo,rn| memo << rn}
      @sent.map(&:name).each {|sn| recvd_names.should include(sn)}
    end
    
    it "should return to the client as many responses as sent messages" do
      @responses.length.should == @sent.length
    end
    
    it "should return to the client an identical message to that which was sent" do
      @received.zip(@responses).each do |recvd,resp|
        recvd.name.should == resp.name
      end
    end
  end
end
