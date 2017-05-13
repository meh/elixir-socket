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

  When creating a socket you can pass a series of options to use for it.

  * `:as` sets the kind of value returned by recv, either `:binary` or `:list`,
    the default is `:binary`.
  * `:mode` can be either `:passive` or `:active`, default is `:passive`
  * `:local` must be a keyword list
    - `:address` the local address to use
    - `:fd` an already opened file descriptor to use
  * `:version` sets the IP version to use
  * `:broadcast` enables broadcast sending

  ## Examples

      server = Socket.UDP.open!(1337)

      { data, client } = server |> Socket.Datagram.recv!
      server |> Socket.Datagram.send! data, client

  """

  @type t :: port

  use Socket.Helpers

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

    :gen_udp.open(port, arguments(options))
  end

  @doc """
  Create a UDP socket listening on the given port and using the given options,
  raising if an error occurs.
  """
  @spec open!(:inet.port_number, Keyword.t) :: t | no_return
  defbang open(port, options)

  @doc """
  Set the process which will receive the messages.
  """
  @spec process(t | port, pid) :: :ok | { :error, :closed | :not_owner | Error.t }
  def process(socket, pid) when socket |> is_port do
    :gen_udp.controlling_process(socket, pid)
  end

  @doc """
  Set the process which will receive the messages, raising if an error occurs.
  """
  @spec process!(t | port, pid) :: :ok | no_return
  def process!(socket, pid) do
    case process(socket, pid) do
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
  def options(socket, opts) when socket |> is_port do
    :inet.setopts(socket, arguments(opts))
  end

  @doc """
  Convert UDP options to `:inet.setopts` compatible arguments.
  """
  @spec arguments(Keyword.t) :: list
  def arguments(options) do
    options = options
      |> Keyword.put_new(:as, :binary)

    options = Enum.group_by(options, fn
      { :as, _ }         -> true
      { :local, _ }      -> true
      { :version, _ }    -> true
      { :broadcast, _ }  -> true
      { :multicast, _ }  -> true
      { :membership, _ } -> true
      _                  -> false
    end)

    { local, global } = {
      Map.get(options, true, []),
      Map.get(options, false, [])
    }

    Socket.arguments(global) ++ Enum.flat_map(local, fn
      { :as, :binary } ->
        [:binary]

      { :as, :list } ->
        [:list]

      { :local, options } ->
        Enum.flat_map(options, fn
          { :address, address } ->
            [{ :ip, Socket.Address.parse(address) }]

          { :fd, fd } ->
            [{ :fd, fd }]
        end)

      { :version, 4 } ->
        [:inet]

      { :version, 6 } ->
        [:inet6]

      { :broadcast, broadcast } ->
        [{ :broadcast, broadcast }]

      { :multicast, options } ->
        Enum.flat_map(options, fn
          { :address, address } ->
            [{ :multicast_if, Socket.Address.parse(address) }]

          { :loop, loop } ->
            [{ :multicast_loop, loop }]

          { :ttl, ttl } ->
            [{ :multicast_ttl, ttl }]
        end)

      { :membership, membership } ->
        [{ :add_membership, membership }]
    end)
  end
end
