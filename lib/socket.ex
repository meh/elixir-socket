#            DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE
#                    Version 2, December 2004
#
#            DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE
#   TERMS AND CONDITIONS FOR COPYING, DISTRIBUTION AND MODIFICATION
#
#  0. You just DO WHAT THE FUCK YOU WANT TO.

defmodule Socket do
  @type t :: Socket.Protocol.t

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

      { :ok, client } = Sockect.connect "tcp://google.com:80"
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
    Socket.Web.connect(host, port, path)
  end

  def connect(%URI{scheme: "wss", host: host, port: port, path: path}) do
    Socket.Web.connect(host, port, path, secure: true)
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
    Socket.Web.connect!(host, port, path)
  end

  def connect!(%URI{scheme: "wss", host: host, port: port, path: path}) do
    Socket.Web.connect!(host, port, path, secure: true)
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

      { :ok, server } = Sockect.listen "tcp://*:1337"
      client = server.accept!(packet: :line)
      client.send(client.recv)
      client.close

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
    Socket.Web.listen(port, local: [address: if(host == "*", do: "0.0.0.0", else: host)])
  end

  def listen(%URI{scheme: "wss", host: host, port: port}) do
    Socket.Web.listen(port, secure: true, local: [address: if(host == "*", do: "0.0.0.0", else: host)])
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
    Socket.Web.listen!(port, local: [address: if(host == "*", do: "0.0.0.0", else: host)])
  end

  def listen!(%URI{scheme: "wss", host: host, port: port}) do
    Socket.Web.listen!(port, secure: true, local: [address: if(host == "*", do: "0.0.0.0", else: host)])
  end

  @doc false
  def arguments(options) do
    args = []

    args = case Keyword.get(options, :mode, :passive) do
      :active ->
        [{ :active, true } | args]

      :once ->
        [{ :active, :once } | args]

      :passive ->
        [{ :active, false } | args]
    end

    if Keyword.has_key?(options, :route) do
      args = [{ :dontroute, !Keyword.get(options, :route) } | args]
    end

    if Keyword.get(options, :reuseaddr) do
      args = [{ :reuseaddr, true } | args]
    end

    if linger = Keyword.get(options, :linger) do
      args = [{ :linger, { true, linger } } | args]
    end

    if priority = Keyword.get(options, :priority) do
      args = [{ :priority, priority } | args]
    end

    if tos = Keyword.get(options, :tos) do
      args = [{ :tos, tos } | args]
    end

    if send = Keyword.get(options, :send) do
      case Keyword.get(send, :timeout) do
        { timeout, :close } ->
          args = [{ :send_timeout, timeout }, { :send_timeout_close, true } | args]

        timeout when timeout |> is_integer ->
          args = [{ :send_timeout, timeout } | args]
      end

      if delay = Keyword.get(send, :delay) do
        args = [{ :delay_send, delay } | args]
      end

      if buffer = Keyword.get(send, :buffer) do
        args = [{ :sndbuf, buffer } | args]
      end
    end

    if recv = Keyword.get(options, :recv) do
      if buffer = Keyword.get(recv, :buffer) do
        args = [{ :recbuf, buffer } | args]
      end
    end

    args
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

  @on_load :uris

  def uris do
    URI.default_port "ws", 80
    URI.default_port "wss", 443
    :ok
  end
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

  def equal?(self, other) when self |> Record.record?(:sslsocket) and other |> Record.record?(:sslsocket) do
    self == other
  end

  def equal?(self, other) when self |> Record.record?(:sslsocket) do
    self |> elem(1) == other
  end

  def equal?(_, _) do
    false
  end

  def accept(self, options \\ []) when self |> Record.record?(:sslsocket) do
    Socket.SSL.accept(self, options)
  end

  def options(self, opts) when self |> Record.record?(:sslsocket) do
    Socket.SSL.options(self, opts)
  end

  def packet(self, type) when self |> Record.record?(:sslsocket) do
    :ssl.setopts(self, packet: type)
  end

  def process(self, pid) when self |> Record.record?(:sslsocket) do
    :ssl.controlling_process(self, pid)
  end

  def active(self) when self |> Record.record?(:sslsocket) do
    :ssl.setopts(self, active: true)
  end

  def active(self, :once) when self |> Record.record?(:sslsocket) do
    :ssl.setopts(self, active: :once)
  end

  def passive(self) when self |> Record.record?(:sslsocket) do
    :ssl.setopts(self, active: false)
  end

  def local(self) when self |> Record.record?(:sslsocket) do
    :ssl.sockname(self)
  end

  def remote(self) when self |> Record.record?(:sslsocket) do
    :ssl.peername(self)
  end

  def close(self) when self |> Record.record?(:sslsocket) do
    :ssl.close(self)
  end
end
