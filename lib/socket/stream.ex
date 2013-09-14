#            DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE
#                    Version 2, December 2004
#
#            DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE
#   TERMS AND CONDITIONS FOR COPYING, DISTRIBUTION AND MODIFICATION
#
#  0. You just DO WHAT THE FUCK YOU WANT TO.

defprotocol Socket.Stream.Protocol do
  @doc """
  Send data through the socket.
  """
  @spec send(t, iodata) :: :ok | { :error, term }
  def send(self, data)

  @doc """
  Send a file through the socket, using non-copying operations where available.
  """
  @spec file(t, String.t)            :: :ok | { :error, term }
  @spec file(t, String.t, Keyword.t) :: :ok | { :error, term }
  def file(self, path, options // [])

  @doc """
  Receive data from the socket compatible with the packet type.
  """
  @spec recv(t) :: { :ok, term } | { :error, term }
  def recv(self)

  @doc """
  Receive data from the socket with the given length or options.
  """
  @spec recv(t, non_neg_integer | Keyword.t) :: { :ok, term } | { :error, term }
  def recv(self, length_or_options)

  @doc """
  Receive data from the socket with the given length and options.
  """
  @spec recv(t, non_neg_integer, Keyword.t) :: { :ok, term } | { :error, term }
  def recv(self, length, options)

  @doc """
  Shutdown the socket in the given mode, either `:both`, `:read`, or `:write`.
  """
  @spec shutdown(t, :both | :read | :write) :: :ok | { :error, term }
  def shutdown(self, how // :both)
end

defmodule Socket.Stream do
  use Socket.Helpers

  defdelegate send(self, data), to: Socket.Stream.Protocol
  defbang     send(self, data), to: Socket.Stream.Protocol

  defdelegate file(self, path), to: Socket.Stream.Protocol
  defbang     file(self, path), to: Socket.Stream.Protocol
  defdelegate file(self, path, options), to: Socket.Stream.Protocol
  defbang     file(self, path, options), to: Socket.Stream.Protocol

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

  def file(self, path, options // []) do
    cond do
      options[:size] && options[:chunk_size] ->
        :file.sendfile(path, self, options[:offset] || 0, options[:size], chunk_size: options[:chunk_size])

      options[:size] ->
        :file.sendfile(path, self, options[:offset] || 0, options[:size], [])

      true ->
        :file.sendfile(path, self)
    end
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
    :gen_tcp.shutdown(self, case how do
      :read  -> :read
      :write -> :write
      :both  -> :read_write
    end)
  end
end

defimpl Socket.Stream.Protocol, for: Tuple do
  def send(self, data) when self |> is_record :sslsocket do
    :ssl.send(self, data)
  end

  def file(self, path, options // []) when self |> is_record :sslsocket do
    cond do
      options[:size] && options[:chunk_size] ->
        :file.sendfile(path, self, options[:offset] || 0, options[:size], chunk_size: options[:chunk_size])

      options[:size] ->
        :file.sendfile(path, self, options[:offset] || 0, options[:size], [])

      true ->
        :file.sendfile(path, self)
    end
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
    :ssl.shutdown(self, case how do
      :read  -> :read
      :write -> :write
      :both  -> :read_write
    end)
  end
end
