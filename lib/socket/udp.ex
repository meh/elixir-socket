#            DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE
#                    Version 2, December 2004
#
#            DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE
#   TERMS AND CONDITIONS FOR COPYING, DISTRIBUTION AND MODIFICATION
#
#  0. You just DO WHAT THE FUCK YOU WANT TO.

defmodule Socket.UDP do
  @moduledoc """
  This module wraps a UDP socket using `gen_udp`.

  ## Options

  When creating a socket you can pass a serie of options to use for it.

  * `:as` sets the kind of value returned by recv, either `:binary` or `:list`,
    the default is `:binary`.
  * `:mode` can be either `:passive` or `:active`, default is `:passive`
  * `:automatic` tells it whether to use smart garbage collection or not, when
    passive the default is `true`, when active the default is `false`
  * `:local` must be a keyword list
    - `:address` the local address to use
    - `:fd` an already opened file descriptor to use
  * `:version` sets the IP version to use
  * `:broadcast` enables broadcast sending

  ## Smart garbage collection

  Normally sockets in Erlang are closed when the controlling process exits,
  with smart garbage collection the controlling process will be the
  `Socket.Manager` and it will be closed when there are no more references to
  it.

  ## Examples

      server = Socket.UDP.open!(1337)

      { data, client } = server.recv!
      client.send! data

  """

  @type t :: record

  defrecordp :udp, __MODULE__, socket: nil, reference: nil

  use Socket.Helpers

  @doc """
  Wrap an existing socket.
  """
  @spec wrap(port) :: t
  def wrap(port) do
    udp(socket: port)
  end

  @doc """
  Create a UDP socket listening on an OS chosen port, use `local` to know the
  port it was bound on.
  """
  @spec open :: { :ok, t } | { :error, Error.t }
  def open do
    open(0, [])
  end

  @doc """
  Create a UDP socket listening on an OS chosen port, use `local` to know the
  port it was bound on, raising if an error occurs.
  """
  @spec open! :: t | no_return
  defbang open

  @doc """
  Create a UDP socket listening on the given port or using the given options.
  """
  @spec open(:inet.port_number | Keyword.t) :: { :ok, t } | { :error, Error.t }
  def open(port) when port |> is_integer do
    open(port, [])
  end

  def open(options) when options |> is_list do
    open(0, options)
  end

  @doc """
  Create a UDP socket listening on the given port or using the given options,
  raising if an error occurs.
  """
  @spec open!(:inet.port_number | Keyword.t) :: t | no_return
  defbang open(port_or_options)

  @doc """
  Create a UDP socket listening on the given port and using the given options.
  """
  @spec open(:inet.port_number, Keyword.t) :: { :ok, t } | { :error, Error.t }
  def open(port, options) do
    options = Keyword.put_new(options, :mode, :passive)

    case :gen_udp.open(port, arguments(options)) do
      { :ok, sock } ->
        reference = if options[:mode] == :passive and options[:automatic] != false do
          :gen_udp.controlling_process(sock, Process.whereis(Socket.Manager))

          Finalizer.define({ :close, :udp, sock }, Process.whereis(Socket.Manager))
        end

        { :ok, udp(socket: sock, reference: reference) }

      error ->
        error
    end
  end

  @doc """
  Create a UDP socket listening on the given port and using the given options,
  raising if an error occurs.
  """
  @spec open!(:ient.port_number, Keyword.t) :: t | no_return
  defbang open(port, options)

  @doc """
  Set the process which will receive the messages.
  """
  @spec process(t | port, pid) :: :ok | { :error, :closed | :not_owner | Error.t }
  def process(udp(socket: sock), pid) do
    process(sock, pid)
  end

  def process(sock, pid) when sock |> is_port do
    :gen_udp.controlling_process(sock, pid)
  end

  @doc """
  Set the process which will receive the messages, raising if an error occurs.
  """
  @spec process!(t | port, pid) :: :ok | no_return
  def process!(sock, pid) do
    case process(sock, pid) do
      :ok ->
        :ok

      :closed ->
        raise RuntimeError, message: "the socket is closed"

      :not_owner ->
        raise RuntimeError, message: "the current process isn't the owner"

      code ->
        raise Socket.Error, reason: code
    end
  end

  @doc """
  Set options of the socket.
  """
  @spec options(t, Keyword.t) :: :ok | { :error, Error.t }
  def options(udp(socket: sock), opts) do
    options(sock, opts)
  end

  def options(sock, opts) when sock |> is_port do
    :inet.setopts(sock, arguments(opts))
  end

  @doc """
  Convert UDP options to `:inet.setopts` compatible arguments.
  """
  @spec arguments(Keyword.t) :: list
  def arguments(options) do
    args = Socket.arguments(options)

    args = case Keyword.get(options, :as, :binary) do
      :list ->
        [:list | args]

      :binary ->
        [:binary | args]
    end

    if local = Keyword.get(options, :local) do
      if address = Keyword.get(local, :address) do
        args = [{ :ip, Socket.Address.parse(address) } | args]
      end

      if fd = Keyword.get(local, :fd) do
        args = [{ :fd, fd } | args]
      end
    end

    args = case Keyword.get(options, :version) do
      4 ->
        [:inet | args]

      6 ->
        [:inet6 | args]

      nil ->
        args
    end

    if Keyword.has_key?(options, :broadcast) do
      args = [{ :broadcast, Keyword.get(options, :broadcast) } | args]
    end

    if multicast = Keyword.get(options, :multicast) do
      if address = Keyword.get(multicast, :address) do
        args = [{ :multicast_if, address } | args]
      end

      if loop = Keyword.get(multicast, :loop) do
        args = [{ :multicast_loop, loop } | args]
      end

      if ttl = Keyword.get(multicast, :ttl) do
        args = [{ :multicast_ttl, ttl } | args]
      end
    end

    if membership = Keyword.get(options, :membership) do
      args = [{ :add_membership, membership } | args]
    end

    args
  end
end

defimpl Socket.Protocol, for: Socket.UDP do
  use Socket.Helpers

  defwrap equal?(self, other)

  definvalid accept(self)
  definvalid accept(self, options)

  defdelegate options(self, options), to: @for
  defwrap packet(self, type)
  defdelegate process(self, pid), to: @for

  defwrap active(self)
  defwrap active(self, mode)
  defwrap passive(self)

  defwrap local(self)
  defwrap remote(self)

  defwrap close(self)
end

defimpl Socket.Datagram.Protocol, for: Socket.UDP do
  use Socket.Helpers

  defwrap send(self, data, to)

  defwrap recv(self)
  defwrap recv(self, length_or_options)
  defwrap recv(self, length, options)
end
