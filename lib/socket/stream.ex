#            DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE
#                    Version 2, December 2004
#
#            DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE
#   TERMS AND CONDITIONS FOR COPYING, DISTRIBUTION AND MODIFICATION
#
#  0. You just DO WHAT THE FUCK YOU WANT TO.

defprotocol Socket.Stream.Protocol do
  def send(self, data)

  def recv(self)
  def recv(self, length_or_options)
  def recv(self, length, options)

  def shutdown(self, how // :both)
end

defmodule Socket.Stream do
  use Socket.Helpers

  defdelegate send(self, data), to: Socket.Stream.Protocol
  defbang     send(self, data), to: Socket.Stream.Protocol

  defdelegate recv(self), to: Socket.Stream.Protocol
  defbang     recv(self), to: Socket.Stream.Protocol
  defdelegate recv(self, length_or_options), to: Socket.Stream.Protocol
  defbang     recv(self, length_or_options), to: Socket.Stream.Protocol
  defdelegate recv(self, length, options), to: Socket.Stream.Protocol
  defbang     recv(self, length, options), to: Socket.Stream.Protocol

  defdelegate shutdown(self), to: Socket.Stream.Protocol
  defbang     shutdown(self), to: Socket.Stream.Protocol
  defdelegate shutdown(self, how), to: Socket.Stream.Protocol
  defbang     shutdown(self, how), to: Socket.Stream.Protocol
end

defimpl Socket.Stream.Protocol, for: Port do
  def send(self, data) do
    :gen_tcp.send(self, data)
  end

  def recv(self) do
    recv(self, 0, [])
  end

  def recv(self, length) when is_integer(length) do
    recv(self, length, [])
  end

  def recv(self, options) when is_list(options) do
    recv(self, 0, options)
  end

  def recv(self, length, options) do
    case :gen_tcp.recv(self, length, options[:timeout] || :infinity) do
      { :ok, _ } = ok ->
        ok

      { :error, :closed } ->
        { :ok, nil }

      { :error, _ } = error ->
        error
    end
  end

  def shutdown(self, how // :both) do
    :gen_tcp.shutdown(self, how)
  end
end

defimpl Socket.Stream.Protocol, for: Tuple do
  def send(self, data) when self |> is_record :sslsocket do
    :ssl.send(self, data)
  end

  def recv(self) when self |> is_record :sslsocket do
    recv(self, 0, [])
  end

  def recv(self, length) when self |> is_record :sslsocket and is_integer(length) do
    recv(self, length, [])
  end

  def recv(self, options) when self |> is_record :sslsocket and is_list(options) do
    recv(self, 0, options)
  end

  def recv(self, length, options) when self |> is_record :sslsocket do
    case :ssl.recv(self, length, options[:timeout] || :infinity) do
      { :ok, _ } = ok ->
        ok

      { :error, :closed } ->
        { :ok, nil }

      { :error, _ } = error ->
        error
    end
  end

  def shutdown(self, how // :both) do
    :ssl.shutdown(self, how)
  end
end
