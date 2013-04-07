module Rbuv
  module EM
    class Connection

      def self.new(sig, *args)
        allocate.instance_eval do
          @signature = sig

          initialize(*args)

          post_init

          self
        end
      end

      def initialize(*args)
      end

      def post_init
      end

      def receive_data(data)
        puts "............>>>#{data.length}"
      end

      def unbind
      end

      def send_data(data)
        data = data.to_s
        size = data.bytesize if data.respond_to?(:bytesize)
        size ||= data.size
        EM.send_data @signature, data, size
      end

      def close_connection(after_writing=false)
        EM.close_connection @signature, after_writing
      end

      def connection_completed
      end

    end
  end
end
