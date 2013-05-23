#            DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE
#                    Version 2, December 2004
#
#            DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE
#   TERMS AND CONDITIONS FOR COPYING, DISTRIBUTION AND MODIFICATION
#
#  0. You just DO WHAT THE FUCK YOU WANT TO.

defmodule Socket do
  @on_load :uris

  @type t :: port | record

  @doc """
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
  @spec connect(String.t | URI.Info.t) :: { :ok, Socket.t } | { :error, any }
  def connect(uri) when is_list(uri) or is_binary(uri) do
    connect(URI.parse(uri))
  end

  def connect(URI.Info[scheme: "tcp", host: host, port: port]) do
    Socket.TCP.connect(host, port)
  end

  def connect(URI.Info[scheme: "ssl", host: host, port: port]) do
    Socket.SSL.connect(host, port)
  end

  def connect(URI.Info[scheme: "ws", host: host, port: port, path: path]) do
    Socket.Web.connect(host, port, path)
  end

  def connect(URI.Info[scheme: "wss", host: host, port: port, path: path]) do
    Socket.Web.connect(host, port, path, secure: true)
  end

  @doc """
  Create a socket connecting to somewhere using an URI, raising if an error
  occurs, see `connect`.
  """
  @spec connect!(String.t | URI.Info.t) :: Socket.t | no_return
  def connect!(uri) when is_list(uri) or is_binary(uri) do
    connect!(URI.parse(uri))
  end

  def connect!(URI.Info[scheme: "tcp", host: host, port: port]) do
    Socket.TCP.connect!(host, port)
  end

  def connect!(URI.Info[scheme: "ssl", host: host, port: port]) do
    Socket.SSL.connect!(host, port)
  end

  def connect!(URI.Info[scheme: "ws", host: host, port: port, path: path]) do
    Socket.Web.connect!(host, port, path)
  end

  def connect!(URI.Info[scheme: "wss", host: host, port: port, path: path]) do
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
  @spec listen(String.t | URI.Info.t) :: { :ok, Socket.t } | { :error, any }
  def listen(uri) when is_list(uri) or is_binary(uri) do
    listen(URI.parse(uri))
  end

  def listen(URI.Info[scheme: "tcp", host: host, port: port]) do
    Socket.TCP.listen(port, local: [address: if(host == "*", do: "0.0.0.0", else: host)])
  end

  def listen(URI.Info[scheme: "ssl", host: host, port: port]) do
    Socket.SSL.listen(port, local: [address: if(host == "*", do: "0.0.0.0", else: host)])
  end

  def listen(URI.Info[scheme: "ws", host: host, port: port]) do
    Socket.Web.listen(port, local: [address: if(host == "*", do: "0.0.0.0", else: host)])
  end

  def listen(URI.Info[scheme: "wss", host: host, port: port]) do
    Socket.Web.listen(port, secure: true, local: [address: if(host == "*", do: "0.0.0.0", else: host)])
  end

  @doc """
  Create a socket listening somewhere using an URI, raising if an error occurs,
  see `listen`.
  """
  @spec listen!(String.t | URI.Info.t) :: Socket.t | no_return
  def listen!(uri) when is_list(uri) or is_binary(uri) do
    listen!(URI.parse(uri))
  end

  def listen!(URI.Info[scheme: "tcp", host: host, port: port]) do
    Socket.TCP.listen!(port, local: [address: if(host == "*", do: "0.0.0.0", else: host)])
  end

  def listen!(URI.Info[scheme: "ssl", host: host, port: port]) do
    Socket.SSL.listen!(port, local: [address: if(host == "*", do: "0.0.0.0", else: host)])
  end

  def listen!(URI.Info[scheme: "ws", host: host, port: port]) do
    Socket.Web.listen!(port, local: [address: if(host == "*", do: "0.0.0.0", else: host)])
  end

  def listen!(URI.Info[scheme: "wss", host: host, port: port]) do
    Socket.Web.listen!(port, secure: true, local: [address: if(host == "*", do: "0.0.0.0", else: host)])
  end

  @doc false
  def arguments(options) do
    args = []

    args = case options[:mode] || :passive do
      :active ->
        [{ :active, true } | args]

      :passive ->
        [{ :active, false } | args]
    end

    if Keyword.has_key?(options, :route) do
      args = [{ :dontroute, !options[:route] } | args]
    end

    if options[:reuseaddr] do
      args = [{ :reuseaddr, true } | args]
    end

    if options[:linger] do
      args = [{ :linger, { true, options[:linger] } } | args]
    end

    if options[:priority] do
      args = [{ :priority, options[:priority] } | args]
    end

    if options[:tos] do
      args = [{ :tos, options[:tos] } | args]
    end

    if send = options[:send] do
      case send[:timeout] do
        { timeout, :close } ->
          args = [{ :send_timeout, timeout }, { :send_timeout_close, true } | args]

        timeout when is_integer(timeout) ->
          args = [{ :send_timeout, timeout } | args]
      end

      if send[:delay] do
        args = [{ :delay_send, send[:delay] } | args]
      end

      if send[:buffer] do
        args = [{ :sndbuf, send[:buffer] } | args]
      end
    end

    if recv = options[:recv] do
      if recv[:buffer] do
        args = [{ :recbuf, recv[:buffer] } | args]
      end
    end

    args
  end

  defp uris do
    Enum.each [URI.WS, URI.WSS], Code.ensure_loaded(&1)

    :ok
  end
end
