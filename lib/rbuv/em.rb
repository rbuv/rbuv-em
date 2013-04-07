require "rbuv/em/version"
require "rbuv"
require "rbuv/em/connection"

ConnectionNotBound = Class.new(Rbuv::Error)

module Rbuv
  module EM

    @reactor_running = false
    @tails = []

    def self.run(blk=nil, tail=nil, &block)
      tail && @tails.unshift(tail)

      b = blk || block
      if reactor_running?
        b && b.call
      else
        @conns = {}
        @acceptors = {}
        @timers = {}
        @tails ||= []
        begin
          @reactor_running = true
          initialize_event_machine
          b && add_timer(0, b)
          run_machine
        ensure
          until @tails.empty?
            @tails.pop.call
          end

          release_machine

          @reactor_running = false
        end
      end
    end

    def self.stop
      Rbuv.stop
    end

    def self.stop_event_loop
      self.stop
    end

    def self.run_block
      run do
        yield
        Rbuv.stop
      end
    end

    def self.reactor_running?
      @reactor_running || false
    end

    def self.add_timer(interval, blk=nil, &block)
      if blk ||= block
        s = add_oneshot_timer((interval.to_f * 1000).to_i, &blk)
        @timers[s] = blk
        s
      end
    end

    def self.add_periodic_timer(interval, blk=nil, &block)
      blk ||= block
      EventMachine::PeriodicTimer.new(interval, blk)
    end

    def self.cancel_timer(timer_or_sig)
      if timer_or_sig.respond_to? :cancel
        timer_or_sig.cancel
      else
        @timers[timer_or_sig] = false if @timers.has_key?(timer_or_sig)
      end
    end

    def self.start_server(server, port=nil, handler=nil, *args, &block)
      begin
        port = Integer(port)
      rescue ArgumentError, TypeError
        # there was no port, so server must be a unix domain socket
        # the port argument is actually the handler, and the handler is one of the args
        args.unshift handler if handler
        handler = port
        port = nil
      end if port

      klass = klass_from_handler(Connection, handler, *args)

      s = if port
            start_tcp_server server, port
          else
            start_unix_server server
          end
      @acceptors[s] = [klass, args, block]
      s
    end

    def self.connect(server, port=nil, handler=nil, *args, &blk)
      bind_connect nil, nil, server, port, handler, *args, &blk
    end

    def self.bind_connect bind_addr, bind_port, server, port=nil, handler=nil, *args
      begin
        port = Integer(port)
      rescue ArgumentError, TypeError
        # there was no port, so server must be a unix domain socket
        # the port argument is actually the handler, and the handler is one of the args
        args.unshift handler if handler
        handler = port
        port = nil
      end if port

      klass = klass_from_handler(Connection, handler, *args)

      s = if port
            if bind_addr
              bind_connect_server bind_addr, bind_port.to_i, server, port
            else
              connect_server server, port
            end
          else
            connect_unix_server server
          end

      c = klass.new s, *args
      @conns[s] = c
      block_given? and yield c
      c
    end

    def self.send_data(tcp, data, _size)
      p [tcp, data, _size]
      tcp.write(data)
    end

    def self.close_connection(tcp, _after_writing)
      tcp.close
    end

    private
    def self.initialize_event_machine
    end

    def self.run_machine
      Rbuv::Loop.run
    end

    def self.release_machine
    end

    def self.add_oneshot_timer(interval)
      Rbuv::Timer.start(interval, 0) { yield }
    end

    def self.klass_from_handler(klass = Connection, handler = nil, *args)
      klass = if handler && handler.is_a?(Class)
                raise ArgumentError, "must provide module or subclass of #{klass.name}" unless klass >= handler
                handler
              elsif handler
                begin
                  handler::EM_CONNECTION_CLASS
                rescue NameError
                  handler::const_set(:EM_CONNECTION_CLASS, Class.new(klass) { include handler })
                end
              else
                klass
              end

      arity = klass.instance_method(:initialize).arity
      expected = arity >= 0 ? arity : -(arity + 1)
      if (arity >= 0 and args.size != expected) or (arity < 0 and args.size < expected)
        raise ArgumentError, "wrong number of arguments for #{klass}#initialize (#{args.size} for #{expected})"
      end

      klass
    end

    def self.start_tcp_server(server, port)
      s = Rbuv::Tcp.new
      s.bind server, port
      s.listen 128 do
        self.on_accept(s)
      end
      s
    end

    def self.start_unix_server(server)
    end

    def self.on_accept(s)
      klass,args,blk = @acceptors[s]
      c_tcp = Rbuv::Tcp.new
      s.accept(c_tcp)
      c = klass.new(c_tcp, *args)
      c_tcp.read_start do |data, error|
        if error.is_a?(EOFError)
          c.unbind
        else
          c.receive_data(data)
        end
      end
      @conns[c_tcp] = c
      blk && blk.call(c)
    end

    def self.connect_server(server, port)
      self.bind_connect_server nil, nil, server, port
    end

    def self.bind_connect_server(bind_addr, bind_port, server, port)
      c = Rbuv::Tcp.new
      c.bind bind_addr, bind_port if bind_addr
      c.connect(server, port) do
        self.on_connect(c)
      end
      c
    end

    def self.on_connect(c_tcp)
      c = @conns[c_tcp] or raise ConnectionNotBound, "received ConnectionCompleted for unknown signature: #{c_tcp}"
      c.connection_completed
      c_tcp.read_start do |data, error|
        if error.is_a?(EOFError)
          c.unbind
        else
          c.receive_data(data)
        end
      end
    end

  end
end
