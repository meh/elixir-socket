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

  ## Examples

      server = Socket.UDP.open!(1337)

      { data, client } = server.recv!
      client.send! data

  """

  defexception Error, code: nil do
    @type t :: Error.t

    def message(self) do
      to_binary(:inet.format_error(self.code))
    end
  end

  @type t :: record

  defrecordp :udp, socket: nil, reference: nil

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
  Create a UDP socket listening on the given port or using the given options.
  """
  @spec open(:inet.port_number | Keyword.t) :: { :ok, t } | { :error, Error.t }
  def open(port) when is_integer(port) do
    open(port, [])
  end

  def open(options) do
    open(0, options)
  end

  @doc """
  Create a UDP socket listening on the given port and using the given options.
  """
  @spec open(:inet.port_number, Keyword.t) :: { :ok, t } | { :error, Error.t }
  def open(port, options) do
    case :gen_udp.open(port, arguments(options)) do
      { :ok, sock } ->
        reference = if (options[:mode] == :passive and options[:automatic] != false) or
                       (options[:mode] == :active  and options[:automatic] == true) do
          :gen_udp.controlling_process(sock, Process.whereis(Socket.Manager))
          Finalizer.define({ :close, :udp, sock }, Process.whereis(Socket.Manager))
        end

        { :ok, udp(socket: sock, reference: reference) }

      error ->
        error
    end
  end

  @doc """
  Create a UDP socket listening on an OS chosen port, use `local` to know the
  port it was bound on, raising if an error occurs.
  """
  @spec open! :: t | no_return
  def open! do
    open!(0, [])
  end

  @doc """
  Create a UDP socket listening on the given port or using the given options,
  raising if an error occurs.
  """
  @spec open!(:inet.port_number | Keyword.t) :: t | no_return
  def open!(port) when is_integer(port) do
    open!(port, [])
  end

  def open!(options) do
    open!(0, options)
  end

  @doc """
  Create a UDP socket listening on the given port and using the given options,
  raising if an error occurs.
  """
  @spec open!(:ient.port_number, Keyword.t) :: t | no_return
  def open!(port, options) do
    case open(port, options) do
      { :ok, socket } ->
        socket

      { :error, code } ->
        raise Error, code: code
    end
  end

  @doc """
  Set the process which will receive the messages.
  """
  @spec process(pid, t) :: :ok | { :error, :closed | :not_owner | Error.t }
  def process(pid, udp(socket: sock)) do
    :gen_udp.controlling_process(sock, pid)
  end

  @doc """
  Set the process which will receive the messages, raising if an error occurs.
  """
  @spec process!(pid, t) :: :ok | no_return
  def process!(pid, udp(socket: sock)) do
    case :gen_udp.controlling_process(sock, pid) do
      :ok ->
        :ok

      :closed ->
        raise RuntimeError, message: "the socket is closed"

      :not_owner ->
        raise RuntimeError, message: "the current process isn't the owner"

      code ->
        raise Error, code: code
    end
  end

  @doc """
  Set options of the socket.
  """
  @spec options(Keyword.t, t) :: :ok | { :error, Error.t }
  def options(opts, udp(socket: sock)) do
    :inet.setopts(sock, arguments(opts))
  end

  @doc """
  Set options of the socket, raising if an error occurs.
  """
  @spec options(Keyword.t, t) :: :ok | no_return
  def options!(opts, self) do
    case options(opts, self) do
      :ok ->
        :ok

      { :error, code } ->
        raise Error, code: code
    end
  end

  @doc """
  Send a packet to the given address and port.
  """
  @spec send(String.t | :inet.ip_address, :inet.port_number, iodata, t) :: :ok | { :error, Error.t }
  def send(address, port, value, udp(socket: sock)) do
    if is_binary(address) do
      address = binary_to_list(address)
    end

    :gen_udp.send(sock, address, port, value)
  end

  @doc """
  Send a packet to the given address and port, raising if an error occurs.
  """
  @spec send(String.t | :inet.ip_address, :inet.port_number, iodata, t) :: :ok | no_return
  def send!(address, port, value, self) do
    case send(address, port, value, self) do
      :ok ->
        :ok

      { :error, code } ->
        raise Error, code: code
    end
  end

  defmodule Association do
    @moduledoc """
    This module wraps a message sent to the listening socket, this way you can
    answer directly to it without having to revert to the standard send.
    """

    @type t :: record

    defrecordp :association, socket: nil, address: nil, port: nil

    @doc false
    def new(socket, address, port) do
      association(socket: socket, address: address, port: port)
    end

    @doc """
    Send a packet to the client.
    """
    @spec send(iodata, t) :: :ok | { :error, Error.t }
    def send(value, association(socket: socket, address: address, port: port)) do
      socket.send(address, port, value)
    end

    @doc """
    Send a packet to the client, raising if an error occurs.
    """
    @spec send!(iodata, t) :: :ok | no_return
    def send!(value, association(socket: socket, address: address, port: port)) do
      socket.send!(address, port, value)
    end
  end

  @doc """
  Receive a packet from the socket, defaults to 512 bytes.
  """
  @spec recv(t) :: { :ok, { iodata, Association.t } } | { :error, Error.t }
  def recv(self) do
    recv(512, self)
  end

  @doc """
  Receive a packet from the socket, with either the given length or the given
  options.
  """
  @spec recv(non_neg_integer | Keyword.t, t) :: { :ok, { iodata, Association.t } } | { :error, Error.t }
  def recv(length, self) when is_integer(length) do
    recv(length, [], self)
  end

  def recv(options, self) do
    recv(512, options, self)
  end

  @doc """
  Receive a packet from the socket, with the given length and options.
  """
  @spec recv(non_neg_integer, Keyword.t, t) :: { :ok, { iodata, Association.t } } | { :error, Error.t }
  def recv(length, options, udp(socket: sock) = self) do
    case :gen_udp.recv(sock, length, options[:timeout] || :infinity) do
      { :ok, { address, port, data } } ->
        { :ok, { data, Association.new(self, address, port) } }

      error ->
        error
    end
  end

  @doc """
  Receive a packet from the socket, defaults to 512 bytes, raising if an error
  occurs.
  """
  @spec recv!(t) :: { iodata, Association.t } | no_return
  def recv!(self) do
    case recv(self) do
      { :ok, packet } ->
        packet

      { :error, code } ->
        raise Error, code: code
    end
  end

  @doc """
  Receive a packet from the socket, with either the given length or the given
  options, raising if an error occurs.
  """
  @spec recv!(non_neg_integer | Keyword.t, t) :: { iodata, Association.t } | no_return
  def recv!(length_or_options, self) do
    case recv(length_or_options, self) do
      { :ok, packet } ->
        packet

      { :error, code } ->
        raise Error, code: code
    end
  end

  @doc """
  Receive a packet from the socket, with the given length and options, raising
  if an error occurs.
  """
  @spec recv!(non_neg_integer, Keyword.t, t) :: { iodata, Association.t } | no_return
  def recv!(length, options, self) do
    case recv(length, options, self) do
      { :ok, packet } ->
        packet

      { :error, code } ->
        raise Error, code: code
    end
  end

  @doc """
  Close the socket, if smart garbage collection is used, the socket will be
  closed automatically when it's not referenced by anything.
  """
  @spec close(t) :: :ok
  def close(udp(socket: sock)) do
    :gen_udp.close(sock)
  end

  @doc """
  Get the underlying port wrapped by the socket.
  """
  @spec to_port(t) :: port
  def to_port(udp(socket: sock)) do
    sock
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
