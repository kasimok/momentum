module Momentum
  module Adapters
    class Proxy
      class Body
        include EventMachine::Deferrable
        
        def call(body)
          body.each do |chunk|
            @body_callback.call(chunk)
          end
        end
      
        def each &blk
          @body_callback = blk
        end
      end

      def initialize(host, port)
        @host, @port = host, port
      end
      
      def call(env)
        dup._call(env)
      end
      
      def _call(env)
        req = env['momentum.request']
        
        url = req.uri.dup
        url.host = @host
        url.port = @port

        http = EventMachine::HttpRequest.new(url).get :head => req.headers
        body = Body.new
        
        http.headers do |headers|
          headers['status'] = headers.http_status
          headers['version'] = headers.http_version
          
          env['async.callback'].call [headers.http_status, headers, body]
        end
        
        http.stream do |chunk|
          body.call [chunk]
        end
        
        http.callback do
          body.succeed
        end
        
        throw(:async)
      end
    end
  end
end