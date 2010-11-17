require 'spec_helper'

describe "zmq xreq/xrep" do
  def xr_tranceive_messages(to_send,&block)
    recvd   = []
    replied = []
    req = nil
    rep = nil
    
    @node = run_reactor do
      addr = rand_addr
      
      rep = zmq_xrep(addr, :bind)
      req = zmq_xreq(addr, :connect)
      
      rep.on_recv do |message,response|
        recvd << {:message => message, :response => response}
        
        response.send_message :name => 'response', :body => {:orig_name => message.name}
      end
       
      to_send.each do |message|
        req.send_message(message) do |reply_message|
          replied << reply_message
        end
      end
    end
    
    {:recvd => recvd, :replied => replied, :handlers => {:req => req, :rep => rep}}
  end
  describe "basic sending and receiving" do
    before(:all) do
      @sent = []
      10.times {|i| @sent << DripDrop::Message.new("test-#{i}")}
      xr_info = xr_tranceive_messages(@sent)
      @recvd    = xr_info[:recvd]
      @replied  = xr_info[:replied]
      @req_handler  = xr_info[:handlers][:req]
      @rep_handler  = xr_info[:handlers][:rep]
    end

    it "should receive all sent messages in order" do
      @sent.zip(@recvd).each do |sent,recvd|
        sent.name.should == recvd[:message].name
      end
    end
    
    it "should receive a reply message for each sent message" do
      @sent.zip(@replied).each do |sent, replied|
        replied.body[:orig_name].should == sent.name
      end
    end
    
    it "should pass a ZMQXrepHandler::Response object to the response callback" do
      @recvd.each do |recvd_item|
        recvd_item[:response].should be_instance_of(DripDrop::ZMQXRepHandler::Response)
      end
    end

    it "should have a monotonically incrementing seq for responses" do
      last_seq = 0
      @recvd.each do |recvd_item|
        recvd_item[:response].seq.should == last_seq + 1
        last_seq = recvd_item[:response].seq
      end
    end
    
    it "should include the identity of the sending socket" do
      @recvd.each do |recvd_item|
        recvd_item[:response].identities.should_not be_nil
      end
    end
    
    it "should send responses back to the proper xreq sender" do
      received_count = 0
      
      run_reactor(0.2) do
        addr = rand_addr
        
        rep  = zmq_xrep(addr, :bind)
        req1 = zmq_xreq(addr, :connect)
        req2 = zmq_xreq(addr, :connect)
        
        rep.on_recv do |message,response|
          response.send_message(message)
        end
         
        r1_msg = DripDrop::Message.new("REQ1 Message")
        r2_msg = DripDrop::Message.new("REQ2 Message")
        
        10.times do
        req1.send_message(r1_msg) do |message|
          received_count += 1
          message.name.should == r1_msg.name
        end
        req2.send_message(r2_msg) do |message|
          received_count += 1
          message.name.should == r2_msg.name
        end
        end
      end
       
      received_count.should == 20
    end
  end
end
