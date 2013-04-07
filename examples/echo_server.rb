lib = File.expand_path('../../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'rbuv/em'

EventMachine = EM = Rbuv::EM

class EchoServer < EM::Connection
  def receive_data(data)
    send_data data
  end
end

class Client < EM::Connection
  def connection_completed
    send_data "Hello, world"
  end

  def receive_data(data)
    close_connection
    EM.stop
  end
end

EM.run do
  Rbuv::Signal.start(Rbuv::Signal::INT) { EM.stop }
  EM.start_server '127.0.0.1', 60000, EchoServer
  EM.connect '127.0.0.1', 60000, Client
end
