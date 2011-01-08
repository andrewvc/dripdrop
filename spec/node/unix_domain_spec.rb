require 'spec_helper'

describe "UNIX Domain Sockets" do
  describe "basic sending and receiving" do
    before(:all) do
      results = {}
      results[:specs_ran] = false
      results[:received]  = []
      
      run_reactor do
        path = '/tmp/dripdrop_test.sock'
        server = unix_domain(path, :bind)
        client = unix_domain(path, :connect)
        
        server.on_recv do |message|
          results[:received] << message
        end
        client.send_message(:name => 'test')
        
        results[:specs_ran] = true
      end
      @results = results
    end
    it "should run without error" do
      @results[:specs_ran].should be_true
    end
    it "should receive one message" do
      @results[:received].length.should >= 1
      @results[:received].first.should be_a(DripDrop::Message)
    end
  end

  describe "multiple writers" do
    before(:all) do
      results = {}
      results[:specs_ran] = false
      results[:received]  = []
      results[:expected_received] = [1,2,3,4]
      
      puts "WTF"
      run_reactor(1) do
        path = '/tmp/dripdrop_test.sock'
        server = unix_domain(path, :bind)
        client_a = unix_domain(path, :connect)
        client_b = unix_domain(path, :connect)
        
        server.on_recv do |message|
          results[:received] << message
        end
        results[:expected_received].each do |i|
          if i.odd?
            client_a.send_message(:name => "#{i}")
          else
            client_b.send_message(:name => "#{i}")
          end
        end
        
        results[:specs_ran] = true
      end
       
      puts "WTF"
      @results = results
    end
    it "should run without error" do
      @results[:specs_ran].should be_true
    end
    it "should receive the expected messages in order" do
      @results[:received].should == @results[:expected_received]
    end
  end
end
