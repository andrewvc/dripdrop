require 'spec_helper'

describe DripDrop::Message do
  describe "basic message" do
    def create_basic
      attrs = {
        :name => 'test',
        :head => {:foo => :bar},
        :body => [:foo, :bar, :baz]
      }
      message = DripDrop::Message.new(attrs[:name],:head => attrs[:head],
                                                   :body => attrs[:body])
      [message, attrs]
    end
    it "should create a basic message without raising an exception" do
      lambda {
        message, attrs = create_basic
      }.should_not raise_exception
    end
    describe "with minimal attributes" do
      it "should create a message with only a name" do
        lambda {
          DripDrop::Message.new('nameonly')
        }.should_not raise_exception
      end
      it "should set the head to an empty hash if nil provided" do
        DripDrop::Message.new('nilhead', :head => nil).head.should == {}
      end
      it "should raise an exception if a non-hash, non-nil head is provided" do
        lambda {
          DripDrop::Message.new('arrhead', :head => [])
        }.should raise_exception(ArgumentError)
      end
    end
    describe "encoding" do
      before(:all) do
        @message, @attrs = create_basic
      end
      it "should encode to valid BERT hash without error" do
        enc = @message.encoded
        enc.should be_a(String)
        BERT.decode(enc).should be_a(Hash)
      end
      it "should decode encoded messages without errors" do
        DripDrop::Message.decode(@message.encoded).should be_a(DripDrop::Message)
      end
      it "should encode to valid JSON without error" do
        enc = @message.json_encoded
        enc.should be_a(String)
        JSON.parse(enc).should be_a(Hash)
      end
      it "should decode JSON encoded messages without errors" do
        DripDrop::Message.decode_json(@message.json_encoded).should be_a(DripDrop::Message)
      end
      it "should convert messages to Hash representations" do
        @message.to_hash.should be_a(Hash)
      end
      it "should be able to turn hash representations back into Message objs" do
        DripDrop::Message.from_hash(@message.to_hash).should be_a(DripDrop::Message)
      end
    end
  end
end
