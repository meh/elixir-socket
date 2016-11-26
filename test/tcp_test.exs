defmodule TcpTest do
  use ExUnit.Case

  test "tcp" do
    {result, server} = Socket.TCP.listen(4444)
    assert result == :ok
    {result2, _} = Socket.TCP.listen(4444)
    assert result2 == :error
    {result, client} = Socket.TCP.connect("127.0.0.1", 4444)
    assert result == :ok
    {result, client2} = server |> Socket.TCP.accept
    assert result == :ok
    assert client |> Socket.Stream.send("test") == :ok
    {result, data} = client2 |> Socket.Stream.recv(4)
    assert result == :ok
    assert data == "test"
    assert client |> Socket.Stream.send("test1") == :ok
    assert client |> Socket.Stream.send("test2") == :ok
    {result, data} = client2 |> Socket.Stream.recv(5)
    assert result == :ok
    assert data == "test1"
    assert client2 |> Socket.Stream.shutdown(:write) == :ok
    {result, data} = client2 |> Socket.Stream.recv(5)
    assert result == :ok
    assert data == "test2"
    assert client |> Socket.Stream.send("test3") == :ok
    {result, data} = client2 |> Socket.Stream.recv(4)
    assert result == :ok
    assert data == "test"
    assert client |> Socket.Stream.shutdown(:write) == :ok
    {result, _} = client |> Socket.Stream.send("test4")
    assert result = :error
    {result, data} = client2 |> Socket.Stream.recv(1)
    assert result == :ok
    assert data == "3"
    assert client |> Socket.Stream.close == :ok
    assert client2 |> Socket.Stream.close == :ok
    assert server |> Socket.Stream.close == :ok
  end
end

