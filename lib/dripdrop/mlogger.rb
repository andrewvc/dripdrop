require 'dripdrop/collector'
require 'uri'
require 'mongo'

class DripDrop
  class MLoggerCollector < Collector
    attr_accessor :mongo_collection
    
    def on_recv(message)
      if @mongo_collection
        @mongo_collection.insert(message.to_hash)
      end
    end
  end

  class MLogger
    attr_reader :sub_address, :sub_reactor, :mongo_host, :mongo_port, :mongo_db,
                :mongo_connection, :mongo_collection

    def initialize(sub_address='tcp://127.0.0.1:2901',mhost='127.0.0.1',mport=27017,mdb='dripdrop')
      @sub_address   = URI.parse(sub_address)
      @sub_collector = MLoggerCollector.new('tcp://127.0.0.1:2901')
      
      @mongo_host, @mongo_port, @mongo_db = mhost, mport, mdb
      @mongo_connection = Mongo::Connection.new(@mongo_host,@mongo_port).db(@mongo_db)
      @mongo_collection = @mongo_connection.collection('raw')
    end

    def run
      @sub_collector.mongo_collection = @mongo_collection
      @sub_collector.run.join
    end
  end
end
