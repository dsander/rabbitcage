class RabbitCage
  class ClientConnection < EventMachine::Connection
    def self.start(host, port)
      $server = EM.start_server(host, port, self)
      LOGGER.info "Listening on #{host}:#{port}"
      LOGGER.info "Send QUIT to quit after waiting for all connections to finish."
      LOGGER.info "Send TERM or INT to quit after waiting for up to 10 seconds for connections to finish."
    end

    def post_init
      LOGGER.info "Accepted #{peer}"
      @buffer = []
      @tries = 0
      @user = 'guest'
      RabbitCage.incr
    end

    def peer
      @peer ||=
      begin
        port, ip = Socket.unpack_sockaddr_in(get_peername)
        "#{ip}:#{port}"
      end
    end

    def receive_data(data)
        handle_data data
    rescue => e
      close_connection
      LOGGER.error "#{e.class} - #{e.message}"
      LOGGER.debug "\n#{e.backtrace.join("\n")}"
    end

    def handle_data(data)
      @timer.cancel if @timer
      data2 = data.dup

      while frame = AMQP::Frame.parse(data2)
        LOGGER.debug "Got frame: " + frame.inspect
        case frame.payload
        when AMQP::Protocol::Connection::Open
          @vhost = frame.payload.virtual_host
        when AMQP::Protocol::Connection::StartOk
          length = frame.payload.response[10].class == String ? frame.payload.response[10].unpack('c').first : frame.payload.response[10]
          @user =  frame.payload.response[11..10+length]
        end

        command = self.filter(frame.payload)
        if command == :deny
          LOGGER.warn generate_log_line(frame.payload, command) if frame.payload.class != AMQP::Protocol::Basic::Get
          resp = AMQP::Protocol::Channel::Close.new(:reply_code => 403,
                                            :reply_text => "ACCESS_REFUSED - access to '#{frame.payload.queue || frame.payload.exchange rescue 'the server'}' in vhost '#{@vhost}' refused for user '#{@user}' by rabbitcage",
                                            :method_id => 10,
                                            :class_id => 50
                                           ).to_frame
          resp.channel = frame.channel
          self.send_data resp.to_s
          return
        else
          LOGGER.info generate_log_line(frame.payload, command) if frame.payload.class != AMQP::Protocol::Basic::Get
        end
      end
      if @server_side || try_server_connect(RabbitCage.rabbit_host, RabbitCage.rabbit_port)
        @server_side.send_data data
      end
    end

    def try_server_connect(host, port)
      @server_side = ServerConnection.request(host, port, self)
      LOGGER.info "Successful connection to #{host}:#{port}."
      true
    rescue => e
      @server_side = nil
      if @tries < 10
        @tries += 1
        LOGGER.error "Failed on server connect attempt #{@tries}. Trying again..."
        @timer.cancel if @timer
        @timer = EventMachine::Timer.new(0.1) do
          self.handle_data
        end
      else
        LOGGER.error "Failed after ten connection attempts."
      end
      false
    end

    def unbind
      @server_side.close_connection_after_writing if @server_side
      RabbitCage.decr
    end
    
    def generate_log_line(payload, command)
      "#{peer} #{command} #{payload.class.to_s[16..-1]}\tuser:#{@user} vh:#{@vhost} q:#{payload.respond_to?(:queue) ? payload.queue : 'nil'} ex:#{payload.respond_to?(:exchange) ? payload.exchange : 'nil'}"
    end
  end
end
