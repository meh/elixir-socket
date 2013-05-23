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
