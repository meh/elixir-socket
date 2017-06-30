#            DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE
#                    Version 2, December 2004
#
#            DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE
#   TERMS AND CONDITIONS FOR COPYING, DISTRIBUTION AND MODIFICATION
#
#  0. You just DO WHAT THE FUCK YOU WANT TO.

defmodule Socket do
  @type t :: Socket.Protocol.t

  @default_port_ws  80
  @default_port_wss 443

  defmodule Error do
    defexception message: nil

    def exception(reason: reason) do
      message = cond do
        msg = Socket.TCP.error(reason) ->
          msg

        msg = Socket.SSL.error(reason) ->
          msg

        true ->
          reason |> to_string
      end

      %Error{message: message}
    end
  end

  @doc ~S"""
  Create a socket connecting to somewhere using an URI.

  ## Supported URIs

  * `tcp://host:port` for Socket.TCP
  * `ssl://host:port` for Socket.SSL
  * `ws://host:port/path` for Socket.Web (using Socket.TCP)
  * `wss://host:port/path` for Socket.Web (using Socket.SSL)
  * `udp://host:port` for Socket:UDP

  ## Example

      { :ok, client } = Socket.connect "tcp://google.com:80"
      client.send "GET / HTTP/1.1\r\n"
      client.recv

  """
  @spec connect(String.t | URI.t) :: { :ok, Socket.t } | { :error, any }
  def connect(uri) when uri |> is_list or uri |> is_binary do
    connect(URI.parse(uri))
  end

  def connect(%URI{scheme: "tcp", host: host, port: port}) do
    Socket.TCP.connect(host, port)
  end

  def connect(%URI{scheme: "ssl", host: host, port: port}) do
    Socket.SSL.connect(host, port)
  end

  def connect(%URI{scheme: "ws", host: host, port: port, path: path}) do
    Socket.Web.connect(host, port || @default_port_ws, path: path)
  end

  def connect(%URI{scheme: "wss", host: host, port: port, path: path}) do
    Socket.Web.connect(host, port || @default_port_wss, path: path, secure: true)
  end

  @doc """
  Create a socket connecting to somewhere using an URI, raising if an error
  occurs, see `connect`.
  """
  @spec connect!(String.t | URI.t) :: Socket.t | no_return
  def connect!(uri) when uri |> is_list or uri |> is_binary do
    connect!(URI.parse(uri))
  end

  def connect!(%URI{scheme: "tcp", host: host, port: port}) do
    Socket.TCP.connect!(host, port)
  end

  def connect!(%URI{scheme: "ssl", host: host, port: port}) do
    Socket.SSL.connect!(host, port)
  end

  def connect!(%URI{scheme: "ws", host: host, port: port, path: path}) do
    Socket.Web.connect!(host, port || @default_port_ws, path: path)
  end

  def connect!(%URI{scheme: "wss", host: host, port: port, path: path}) do
    Socket.Web.connect!(host, port || @default_port_wss, path: path, secure: true)
  end

  @doc """
  Create a socket listening somewhere using an URI.

  ## Supported URIs

  If host is `*` it will be converted to `0.0.0.0`.

  * `tcp://host:port` for Socket.TCP
  * `ssl://host:port` for Socket.SSL
  * `ws://host:port/path` for Socket.Web (using Socket.TCP)
  * `wss://host:port/path` for Socket.Web (using Socket.SSL)
  * `udp://host:port` for Socket:UDP

  ## Example

      { :ok, server } = Socket.listen "tcp://*:1337"
      client = server |> Socket.accept!(packet: :line)
      client |> Socket.Stream.send(client.recv)
      client |> Socket.Stream.close

  """
  @spec listen(String.t | URI.t) :: { :ok, Socket.t } | { :error, any }
  def listen(uri) when uri |> is_list or uri |> is_binary do
    listen(URI.parse(uri))
  end

  def listen(%URI{scheme: "tcp", host: host, port: port}) do
    Socket.TCP.listen(port, local: [address: if(host == "*", do: "0.0.0.0", else: host)])
  end

  def listen(%URI{scheme: "ssl", host: host, port: port}) do
    Socket.SSL.listen(port, local: [address: if(host == "*", do: "0.0.0.0", else: host)])
  end

  def listen(%URI{scheme: "ws", host: host, port: port}) do
    Socket.Web.listen(port || @default_port_ws, local: [address: if(host == "*", do: "0.0.0.0", else: host)])
  end

  def listen(%URI{scheme: "wss", host: host, port: port}) do
    Socket.Web.listen(port || @default_port_wss, secure: true, local: [address: if(host == "*", do: "0.0.0.0", else: host)])
  end

  @doc """
  Create a socket listening somewhere using an URI, raising if an error occurs,
  see `listen`.
  """
  @spec listen!(String.t | URI.t) :: Socket.t | no_return
  def listen!(uri) when uri |> is_list or uri |> is_binary do
    listen!(URI.parse(uri))
  end

  def listen!(%URI{scheme: "tcp", host: host, port: port}) do
    Socket.TCP.listen!(port, local: [address: if(host == "*", do: "0.0.0.0", else: host)])
  end

  def listen!(%URI{scheme: "ssl", host: host, port: port}) do
    Socket.SSL.listen!(port, local: [address: if(host == "*", do: "0.0.0.0", else: host)])
  end

  def listen!(%URI{scheme: "ws", host: host, port: port}) do
    Socket.Web.listen!(port || @default_port_ws, local: [address: if(host == "*", do: "0.0.0.0", else: host)])
  end

  def listen!(%URI{scheme: "wss", host: host, port: port}) do
    Socket.Web.listen!(port || @default_port_wss, secure: true, local: [address: if(host == "*", do: "0.0.0.0", else: host)])
  end

  @doc false
  def arguments(options) do
    options = options
      |> Keyword.put_new(:mode, :passive)

    Enum.flat_map(options, fn
      { :mode, :active } ->
        [{ :active, true }]

      { :mode, :once } ->
        [{ :active, :once }]

      { :mode, :passive } ->
        [{ :active, false }]

      { :route, true } ->
        [{ :dontroute, false }]

      { :route, false } ->
        [{ :dontroute, true }]

      { :reuse, true } ->
        [{ :reuseaddr, true }]

      { :reuse, false } ->
        []

      { :linger, value } ->
        [{ :linger, { true, value } }]

      { :priority, value } ->
        [{ :priority, value }]

      { :tos, value } ->
        [{ :tos, value }]

      { :send, options } ->
        Enum.flat_map(options, fn
          { :timeout, { timeout, :close } } ->
            [{ :send_timeout, timeout }, { :send_timeout_close, true }]

          { :timeout, timeout } when timeout |> is_integer ->
            [{ :send_timeout, timeout }]

          { :delay, delay } ->
            [{ :delay_send, delay }]

          { :buffer, buffer } ->
            [{ :sndbuf, buffer }]
        end)

      { :recv, options } ->
        Enum.flat_map(options, fn
          { :buffer, buffer } ->
            [{ :recbuf, buffer }]
        end)
    end)
  end

  use Socket.Helpers

  defdelegate equal?(self, other), to: Socket.Protocol

  defdelegate accept(self), to: Socket.Protocol
  defbang accept(self), to: Socket.Protocol

  defdelegate accept(self, options), to: Socket.Protocol
  defbang accept(self, options), to: Socket.Protocol

  defdelegate options(self, opts), to: Socket.Protocol
  defbang options(self, opts), to: Socket.Protocol

  defdelegate packet(self, type), to: Socket.Protocol
  defbang packet(self, type), to: Socket.Protocol

  defdelegate process(self, pid), to: Socket.Protocol
  defbang process(self, pid), to: Socket.Protocol

  defdelegate active(self), to: Socket.Protocol
  defbang active(self), to: Socket.Protocol

  defdelegate active(self, mode), to: Socket.Protocol
  defbang active(self, mode), to: Socket.Protocol

  defdelegate passive(self), to: Socket.Protocol
  defbang passive(self), to: Socket.Protocol

  defdelegate local(self), to: Socket.Protocol
  defbang local(self), to: Socket.Protocol

  defdelegate remote(self), to: Socket.Protocol
  defbang remote(self), to: Socket.Protocol

  defdelegate close(self), to: Socket.Protocol
  defbang close(self), to: Socket.Protocol

end

defprotocol Socket.Protocol do
  @doc """
  Check the two sockets are the same.
  """
  @spec equal?(t, t) :: boolean
  def equal?(self, other)

  @doc """
  Accept a connection from the socket.
  """
  @spec accept(t)            :: { :ok, t } | { :error, term }
  @spec accept(t, Keyword.t) :: { :ok, t } | { :error, term }
  def accept(self, options \\ [])

  @doc """
  Set options for the socket.
  """
  @spec options(t, Keyword.t) :: :ok | { :error, term }
  def options(self, opts)

  @doc """
  Change the packet type of the socket.
  """
  @spec packet(t, atom) :: :ok | { :error, term }
  def packet(self, type)

  @doc """
  Change the controlling process of the socket.
  """
  @spec process(t, pid) :: :ok | { :error, term }
  def process(self, pid)

  @doc """
  Make the socket active.
  """
  @spec active(t) :: :ok | { :error, term }
  def active(self)

  @doc """
  Make the socket active once.
  """
  @spec active(t, :once) :: :ok | { :error, term }
  def active(self, mode)

  @doc """
  Make the socket passive.
  """
  @spec passive(t) :: :ok | { :error, term }
  def passive(self)

  @doc """
  Get the local address/port of the socket.
  """
  @spec local(t) :: { :ok, { Socket.Address.t, :inet.port_number } } | { :error, term }
  def local(self)

  @doc """
  Get the remote address/port of the socket.
  """
  @spec remote(t) :: { :ok, { Socket.Address.t, :inet.port_number } } | { :error, term }
  def remote(self)

  @doc """
  Close the socket.
  """
  @spec close(t) :: :ok | { :error, term }
  def close(self)
end

defimpl Socket.Protocol, for: Port do
  def equal?(self, other) when other |> is_port do
    self == other
  end

  def equal?(self, other) do
    self == elem(other, 1)
  end

  def accept(self, options \\ []) do
    case :inet_db.lookup_socket(self) do
      { :ok, mod } when mod in [:inet_tcp, :inet6_tcp] ->
        Socket.TCP.accept(self, options)

      { :ok, mod } when mod in [:inet_udp, :inet6_udp] ->
        { :error, :einval }
    end
  end

  def options(self, opts) do
    :inet.setopts(self, Socket.arguments(opts))
  end

  def packet(self, type) do
    :inet.setopts(self, packet: type)
  end

  def process(self, pid) do
    case :inet_db.lookup_socket(self) do
      { :ok, mod } when mod in [:inet_tcp, :inet6_tcp] ->
        :gen_tcp.controlling_process(self, pid)

      { :ok, mod } when mod in [:inet_udp, :inet6_udp] ->
        :gen_udp.controlling_process(self, pid)
    end
  end

  def active(self) do
    :inet.setopts(self, active: true)
  end

  def active(self, :once) do
    :inet.setopts(self, active: :once)
  end

  def passive(self) do
    :inet.setopts(self, active: false)
  end

  def local(self) do
    :inet.sockname(self)
  end

  def remote(self) do
    :inet.peername(self)
  end

  def close(self) do
    :inet.close(self)
  end
end

defimpl Socket.Protocol, for: Tuple do
  require Record

  def equal?(self, other) when self |> Record.is_record(:sslsocket) and other |> Record.is_record(:sslsocket) do
    self == other
  end

  def equal?(self, other) when self |> Record.is_record(:sslsocket) do
    self |> elem(1) == other
  end

  def equal?(_, _) do
    false
  end

  def accept(self, options \\ []) when self |> Record.is_record(:sslsocket) do
    Socket.SSL.accept(self, options)
  end

  def options(self, opts) when self |> Record.is_record(:sslsocket) do
    Socket.SSL.options(self, opts)
  end

  def packet(self, type) when self |> Record.is_record(:sslsocket) do
    :ssl.setopts(self, packet: type)
  end

  def process(self, pid) when self |> Record.is_record(:sslsocket) do
    :ssl.controlling_process(self, pid)
  end

  def active(self) when self |> Record.is_record(:sslsocket) do
    :ssl.setopts(self, active: true)
  end

  def active(self, :once) when self |> Record.is_record(:sslsocket) do
    :ssl.setopts(self, active: :once)
  end

  def passive(self) when self |> Record.is_record(:sslsocket) do
    :ssl.setopts(self, active: false)
  end

  def local(self) when self |> Record.is_record(:sslsocket) do
    :ssl.sockname(self)
  end

  def remote(self) when self |> Record.is_record(:sslsocket) do
    :ssl.peername(self)
  end

  def close(self) when self |> Record.is_record(:sslsocket) do
    :ssl.close(self)
  end
end
