Elixir sockets made decent
==========================
This library wraps `gen_tcp`, `gen_udp` and `gen_sctp`, `ssl` and implements
websockets, it also implements smart garbage collection (if sockets aren't
referenced anywhere, they are closed).

Building outside of Mix
-----------------------
If you're cloning the repo, make sure to clone it to `socket` and not
`elixir-socket`, or Mix will complain when compiling it.

When used as dependency it won't be a problem, Mix will do the right thing.

Examples
--------

```elixir
defmodule HTTP do
  def get(uri) when is_binary(uri) or is_list(uri) do
    get(URI.parse(uri))
  end

  def get(URI.Info[host: host, port: port, path: path]) do
    sock = Socket.TCP.connect! host, port, packet: :line
    sock |> Socket.Stream.send! "GET #{path || "/"} HTTP/1.1\r\nHost: #{host}\r\n\r\n"

    [_, code, text] = Regex.run %r"HTTP/1.1 (.*?) (.*?)\s*$", sock |> Socket.Stream.recv!

    headers = headers([], sock)

    sock |> Socket.packet! :raw
    body = sock |> Socket.Stream.recv!(binary_to_integer(headers["Content-Length"]))

    { { binary_to_integer(code), text }, headers, body }
  end

  defp headers(acc, sock) do
    case sock |> Socket.Stream.recv! do
      "\r\n" ->
        acc

      line ->
        [_, name, value] = Regex.run %r/^(.*?):\s*(.*?)\s*$/, line

        headers([{ name, value } | acc], sock)
    end
  end
end
```

Connecting to a Websocket
-------------------------
```elixir
defmodule Ws do
  def simple_ws_conn() do
    {:ok, sock} = Socket.Web.connect("echo.websocket.org")
    sock.send({:text, "hello there"}) # you can also send binary using {:binary, "hello there"})
    {:ok, data} = sock.recv
    IO.inspect data
  end
end
```
