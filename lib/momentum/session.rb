module Momentum
  class Session < ::EventMachine::Connection
    attr_accessor :backend
    
    def initialize(*args)
      super
      @zlib = SPDY::Zlib.new
      
      @df = SPDY::Protocol::Data::Frame.new
      @sr = SPDY::Protocol::Control::SynReply.new({:zlib_session => @zlib})
      
      @stream_id = 1
      @parser = ::SPDY::Parser.new
      @parser.on_headers_complete do |stream_id, associated_stream, priority, headers|
        req = Request.new(stream_id: stream_id, associated_stream: associated_stream, priority: priority, headers: headers, zlib: @zlib)
        logger.info "got a request to #{req.uri}"
        
        #@streams << req
        
        status, headers, body = @backend.dispatch(req)
        
        send_syn_reply 1, headers
        
        body.each do |chunk|
          send_data_frame 1, chunk
        end
        send_fin 1
      end
      
      @parser.on_body             { |stream_id, data| 
      
      }
      @parser.on_message_complete { |stream_id| 
      
      }
      
      @parser.on_ping do |id|
        pong = SPDY::Protocol::Control::Ping.new
        pong.ping_id = id
        send_data pong.to_binary_s
      end

      @streams = []
    end
  
    def post_init
      peername = get_peername
      if peername
        @peer = Socket.unpack_sockaddr_in(peername).pop
        logger.info "Connection from: #{@peer}"
      end
    end
    
    def send_data(data)
      logger.debug "<< #{data.inspect}"
      super
    end
  
    def receive_data(data)
      logger.debug ">> #{data.inspect}"
      @parser << data
    end
  
    protected
    
    def send_syn_reply(stream, headers)
      send_data @sr.create({:stream_id => stream, :headers => headers}).to_binary_s
    end
    
    def send_data_frame(stream, data)
      send_data @df.create(:stream_id => stream, :data => data).to_binary_s
    end
    
    def send_fin(stream)
      send_data @df.create(:stream_id => stream, :flags => 1, :data => '').to_binary_s
    end
    
    def logger
      Momentum.logger
    end
  end
end