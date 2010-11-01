require 'dripdrop'
Thread.abort_on_exception = true #Always a good idea in multithreaded apps.

# This demo app is an message stats application
# It receives stats data via either HTTP or ZMQ directly, aggregates,
# and keeps track of data.
DripDrop::Node.new do
  routes_for :agg do
    route :input,  :zmq_subscribe, 'tcp://127.0.0.1:2200', :bind
    route :output, :zmq_publish,   'tcp://127.0.0.1:2201', :bind
    route :input_http, :http_server, 'http://127.0.0.1:8082'
  end
 
  routes_for :counter do
    route :input,      :zmq_subscribe, agg_output.address, :connect
    route :query,      :zmq_xrep,      'tcp://127.0.0.1:2203', :bind
    route :query_http, :http_server,   'tcp://0.0.0.0:8081'
  end

  routes_for :tracer do
    route :input,  :zmq_subscribe, agg_output.address, :connect, :topic_filter => /^ip_trace_req$/
    route :output, :zmq_publish, 'tcp://127.0.0.1:2204', :bind
  end
  
  routes_for :ws_stream do
    route :tracer_input, :zmq_subscribe, agg_output.address,    :connect
    route :agg_input,    :zmq_subscribe, tracer_output.address, :connect
    route :client,       :websocket,     'ws://127.0.0.1:2202'
  end
  
  routes_for :heartbeat do
    route :output, :zmq_publish, agg_input.address, :connect
  end

  nodelet :agg do |agg|
    agg.input.on_recv do |message|
      agg.output.send_message(message)
    end
    
    agg.input.on_recv do |message|
      agg.output.send_message(message)
    end
    
    agg.input_http.on_recv do |message,response,env|
      response.send_message(:name => 'ack')
      agg.output.send_message(message)
    end
  end 

  nodelet :counter do |cntr|
    stats = {:total => 0, :name_counts => Hash.new(0) }
    
    cntr.input.on_recv do |message|
      stats[:total] += 1
      stats[:name_counts][message.name] += 1
    end
    
    cntr.query.on_recv do |message,ids,seq|
      cntr.query.send_message({:name => 'stats', :body => @stats}, ids, seq)
    end

    cntr.query_http.on_recv do |message,response|
      response.send_message(:name => 'stats', :body => @stats)
    end
  end

  nodelet :tracer do |tracer|
    tracer_memo = {}
    
    ip_regexp = /\A(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\Z/
    tracer.input.on_recv do |message|
      puts "TRACE #{message.body.inspect}"
       
      ip = message.body['ip']
      puts "IP #{message.inspect}"
      if ip =~ ip_regexp
        memoized_res = tracer_memo[ip]
        if memoized_res
          tracer.output.send_message(:name => 'ip_route', :body => {:ip => ip, :route => memoized_res})
        else
          EM.system("/usr/sbin/traceroute -w 4 #{ip}") do |output,status|
            route = output.split("\n")[1..-1].map {|l| l.split(/ /)[3] }.select {|a| a != '*'}
            tracer_memo[ip] = route
            tracer.output.send_message(:name => 'ip_route', :body => {:ip => ip, :route => route})
          end
        end
      end
    end
  end

  nodelet :ws_stream do |wss|
    [wss.tracer_input, wss.agg_input].each do |input|
      input.on_recv do |message|
        send_internal(:wss, message)
      end
    end
    
    wss.client.on_open do |ws|
      recv_internal(:wss, ws.signature) do |message|
        ws.send_message(message)
      end
    end.on_recv do |message,ws|
    end.on_close do |ws|
    end.on_error do |ws|
    end
  end
  
  nodelet :heartbeat do |hbeat|
    zm_reactor.periodical_timer(1000) do
      hbeat.output.send_message(:name => 'heartbeat/tick', :body => Time.now.to_i)
    end
  end
end.start! #Start the reactor and block until complete
