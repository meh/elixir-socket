Elixir sockets made decent
==========================
This library wraps `gen_tcp`, `gen_udp` and `gen_sctp`, `ssl` and implements
websockets and socks.

Examples
--------

```elixir
defmodule HTTP do
  def get(uri) when is_binary(uri) or is_list(uri) do
    get(URI.parse(uri))
  end

  def get(%URI{host: host, port: port, path: path}) do
    sock = Socket.TCP.connect! host, port, packet: :line
    sock |> Socket.Stream.send! "GET #{path || "/"} HTTP/1.1\r\nHost: #{host}\r\n\r\n"

    [_, code, text] = Regex.run ~r"HTTP/1.1 (.*?) (.*?)\s*$", sock |> Socket.Stream.recv!

    headers = headers([], sock) |> Enum.into(%{})

    sock |> Socket.packet! :raw
    body = sock |> Socket.Stream.recv!(String.to_integer(headers["Content-Length"]))

    { { String.to_integer(code), text }, headers, body }
  end

  defp headers(acc, sock) do
    case sock |> Socket.Stream.recv! do
      "\r\n" ->
        acc

      line ->
        [_, name, value] = Regex.run ~r/^(.*?):\s*(.*?)\s*$/, line

        headers([{ name, value } | acc], sock)
    end
  end
end
```

Websockets
----------

### Client

```elixir
socket = Socket.Web.connect! "echo.websocket.org"
socket |> Socket.Web.send! { :text, "test" }
socket |> Socket.Web.recv! # => {:text, "test"}
```

### Server

```elixir
server = Socket.Web.listen! 80
client = server |> Socket.Web.accept!

# here you can verify if you want to accept the request or not, call
# `Socket.Web.close!` if you don't want to accept it, or else call
# `Socket.Web.accept!`
client |> Socket.Web.accept!

# echo the first message
client |> Socket.Web.send!(client |> Socket.Web.recv!)
```
