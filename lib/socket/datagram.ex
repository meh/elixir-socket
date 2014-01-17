#            DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE
#                    Version 2, December 2004
#
#            DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE
#   TERMS AND CONDITIONS FOR COPYING, DISTRIBUTION AND MODIFICATION
#
#  0. You just DO WHAT THE FUCK YOU WANT TO.

defprotocol Socket.Datagram.Protocol do
  @doc """
  Send a packet to the given recipient.
  """
  @spec send(t, iodata, term) :: :ok | { :error, term }
  def send(self, data, to)

  @doc """
  Receive a packet from the socket.
  """
  @spec recv(t) :: { :ok, iodata } | { :error, term }
  def recv(self)

  @doc """
  Receive a packet with the given options or with the given size.
  """
  @spec recv(t, non_neg_integer | Keyword.t) :: { :ok, iodata } | { :error, term }
  def recv(self, length_or_options)

  @doc """
  Receive a packet with the given size and options.
  """
  @spec recv(t, non_neg_integer, Keyword.t) :: { :ok, iodata } | { :error, term }
  def recv(self, length, options)
end

defmodule Socket.Datagram do
  @type t :: Socket.Datagram.Protocol.t

  use Socket.Helpers

  defdelegate send(self, packet, to), to: Socket.Datagram.Protocol
  defbang send(self, packet, to), to: Socket.Datagram.Protocol

  defdelegate recv(self), to: Socket.Datagram.Protocol
  defbang     recv(self), to: Socket.Datagram.Protocol
  defdelegate recv(self, length_or_options), to: Socket.Datagram.Protocol
  defbang     recv(self, length_or_options), to: Socket.Datagram.Protocol
  defdelegate recv(self, length, options), to: Socket.Datagram.Protocol
  defbang     recv(self, length, options), to: Socket.Datagram.Protocol
end

defimpl Socket.Datagram.Protocol, for: Port do
  def send(self, data, { address, port }) do
    if address |> is_binary do
      address = address |> String.to_char_list!
    end

    :gen_udp.send(self, address, port, data)
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
    case :gen_udp.recv(self, length, options[:timeout] || :infinity) do
      { :ok, { address, port, data } } ->
        { :ok, { data, { address, port } } }

      { :error, :closed } ->
        { :ok, nil }

      { :error, _ } = error ->
        error
    end
  end
end
