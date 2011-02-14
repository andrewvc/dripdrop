require 'spec_helper'

describe "websockets" do
  def websockets_send_messages(to_send,&block)
    received  = []
    responses = []
    seen_signatures = Set.new
    server = nil
    
    open_message  = DripDrop::Message.new('open',  :body => 'test')
    open_received = false
    
    close_occured = false
    
    error_occured = false
    
    @node = run_reactor(2) do
      addr = rand_addr('ws')
      
      server = websocket(addr)
      server.on_open do |conn|
        conn.send_message(open_message)
        seen_signatures << conn.signature
      end.on_recv do |message,conn|
        received << message
        conn.send_message(message)
      end.on_close do |conn|
        close_occured = true
      end.on_error do |reason,conn|
        error_occured = true
      end
      
      EM.defer do
        client = WebSocket.new(addr)
        open_received = DripDrop::Message.decode(client.receive)
        to_send.each do |message|
          client.send(message.json_encoded)
        end
        
        recvd_count = 0
        while recvd_count < to_send.length && (message = client.receive)
          responses << DripDrop::Message.decode_json(message)
          recvd_count += 1
        end
        client.close
        
        # This one only connects to test unique signatures
        client2 = WebSocket.new(addr)
        client2.close
      end
      
      zmq_subscribe(rand_addr, :bind) {} #Keep zmqmachine happy
    end
    
    {:received => received, :responses => responses, 
     :open_message => open_message,   :open_received => open_received,
     :close_occured => close_occured, :error_occured => error_occured,
     :seen_signatures => seen_signatures,:handlers => {:server => server }}
  end
  describe "basic sending and receiving" do
    before(:all) do
      @sent = []
      10.times {|i| @sent << DripDrop::Message.new("test-#{i}")}
      @ws_info = websockets_send_messages(@sent)
    end

    it "should receive all sent messages" do
      recvd_names = @ws_info[:received].map(&:name).inject(Set.new) {|memo,rn| memo << rn}
      @sent.map(&:name).each {|sn| recvd_names.should include(sn)}
    end
    
    it "should return to the client as many responses as sent messages" do
      @ws_info[:responses].length.should == @sent.length
    end
    
    it "should return to the client an identical message to that which was sent" do
      @ws_info[:received].zip(@ws_info[:responses]).each do |recvd,resp|
        recvd.name.should == resp.name
      end
    end

    it "should generate an on open message" do
      @ws_info[:open_received].to_hash.should == @ws_info[:open_message].to_hash
    end
    
    it "should generate a close event" do
      @ws_info[:close_occured].should be_true
    end

    it "should not generate an error event" do
      @ws_info[:error_occured].should be_false
    end
    
    it "should see unique connection signatures for each client" do
      @ws_info[:seen_signatures].length.should == 2
    end
  end
end
