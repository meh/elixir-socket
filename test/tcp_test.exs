Code.require_file "../test_helper.exs", __FILE__

defmodule TcpTest do
  use ExUnit.Case

  test :connect do
    assert Socket.TCP.connect('127.0.0.1', 1) == { :error, :econnrefused }
    assert Socket.TCP.connect("127.0.0.1", 1) == { :error, :econnrefused }
    assert Socket.TCP.connect({127,0,0,1}, 1) == { :error, :econnrefused }
  end

  test :connect! do
    assert_raise Socket.Error, fn ->
      Socket.TCP.connect!('127.0.0.1', 1) == { :error, :econnrefused }
    end

    assert_raise Socket.Error, fn ->
      Socket.TCP.connect!("127.0.0.1", 1) == { :error, :econnrefused }
    end

    assert_raise Socket.Error, fn ->
      Socket.TCP.connect!({127,0,0,1}, 1) == { :error, :econnrefused }
    end
  end

  test :listen do
    { :ok, socket } = Socket.TCP.listen

    assert is_record(socket, Socket.TCP)
  end

  test :listen! do
    assert is_record(Socket.TCP.listen!, Socket.TCP)
  end

  test :local do
    socket = Socket.TCP.listen! local: [address: "127.0.0.1", port: 58433]
    assert socket.local == { :ok, { {127,0,0,1}, 58433 } }
  end

  test :local! do
    socket = Socket.TCP.listen! local: [address: "127.0.0.1", port: 58433]
    assert socket.local! == { {127,0,0,1}, 58433 }
  end

  test :accept do
    server = Socket.TCP.listen!
    assert server.accept(timeout: 1000) == { :error, :timeout }

    Process.spawn fn ->
      { _, port } = server.local!

      Socket.TCP.connect(Socket.Host.name, port)
    end

    { :ok, client } = server.accept(timeout: 5000)
    assert is_record(client, Socket.TCP)
  end
end
