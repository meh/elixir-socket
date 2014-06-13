#            DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE
#                    Version 2, December 2004
#
#            DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE
#   TERMS AND CONDITIONS FOR COPYING, DISTRIBUTION AND MODIFICATION
#
#  0. You just DO WHAT THE FUCK YOU WANT TO.

defmodule Socket.TCP do
  @moduledoc """
  This module wraps a passive TCP socket using `gen_tcp`.

  ## Options

  When creating a socket you can pass a serie of options to use for it.

  * `:as` sets the kind of value returned by recv, either `:binary` or `:list`,
    the default is `:binary`
  * `:mode` can be either `:passive` or `:active`, default is `:passive`
  * `:local` must be a keyword list
    - `:address` the local address to use
    - `:port` the local port to use
    - `:fd` an already opened file descriptor to use
  * `:backlog` sets the listen backlog
  * `:watermark` must be a keyword list
    - `:low` defines the `:low_watermark`, see `inet:setopts`
    - `:high` defines the `:high_watermark`, see `inet:setopts`
  * `:version` sets the IP version to use
  * `:options` must be a list of atoms
    - `:keepalive` sets `SO_KEEPALIVE`
    - `:nodelay` sets `TCP_NODELAY`
  * `:packet` see `inet:setopts`
  * `:size` sets the max length of the packet body, see `inet:setopts`

  ## Examples

      server = Socket.TCP.listen!(1337, packet: :line)

      client = server |> Socket.Stream.accept!
      client |> Socket.Stream.send!(client |> Socket.Stream.recv!)
      client |> Socket.close

  """

  use Socket.Helpers
  require Record

  @opaque t :: port

  @doc """
  Return a proper error string for the given code or nil if it can't be
  converted.
  """
  @spec error(term) :: String.t
  def error(code) do
    case :inet.format_error(code) do
      'unknown POSIX error' ->
        nil

      message ->
        message |> to_string
    end
  end

  @doc """
  Create a TCP socket connecting to the given host and port tuple.
  """
  @spec connect({ Socket.Address.t, :inet.port_number }) :: { :ok, t } | { :error, Socket.Error.t }
  def connect({ address, port }) do
    connect(address, port)
  end

  @doc """
  Create a TCP socket connecting to the given host and port tuple, raising if
  an error occurs.
  """
  @spec connect({ Socket.Address.t, :inet.port_number }) :: t | no_return
  defbang connect(descriptor)

  @doc """
  Create a TCP socket connecting to the given host and port tuple and options,
  or to the given host and port.
  """
  @spec connect({ Socket.Address.t, :inet.port_number } | Socket.Address.t, Keyword.t | :inet.port_number) :: { :ok, t } | { :error, Socket.Error.t }
  def connect({ address, port }, options) when options |> is_list do
    connect(address, port, options)
  end

  def connect(address, port) when port |> is_integer do
    connect(address, port, [])
  end

  @doc """
  Create a TCP socket connecting to the given host and port tuple and options,
  or to the given host and port, raising if an error occurs.
  """
  @spec connect({ Socket.Address.t, :inet.port_number } | Socket.Address.t, Keyword.t | :inet.port_number) :: t | no_return
  defbang connect(address, port)

  @doc """
  Create a TCP socket connecting to the given host and port.
  """
  @spec connect(String.t | :inet.ip_address, :inet.port_number, Keyword.t) :: { :ok, t } | { :error, Socket.Error.t }
  def connect(address, port, options) when address |> is_binary do
    options = Keyword.put_new(options, :mode, :passive)

    :gen_tcp.connect(String.to_char_list(address), port, arguments(options), options[:timeout] || :infinity)
  end

  @doc """
  Create a TCP socket connecting to the given host and port, raising in case of
  error.
  """
  @spec connect!(String.t | :inet.ip_address, :inet.port_number, Keyword.t) :: t | no_return
  defbang connect(address, port, options)

  @doc """
  Create a TCP socket listening on an OS chosen port, use `local` to know the
  port it was bound on.
  """
  @spec listen :: { :ok, t } | { :error, Socket.Error.t }
  def listen do
    listen(0, [])
  end

  @doc """
  Create a TCP socket listening on an OS chosen port, use `local` to know the
  port it was bound on, raising in case of error.
  """
  @spec listen! :: t | no_return
  defbang listen

  @doc """
  Create a TCP socket listening on an OS chosen port using the given options or
  listening on the given port.
  """
  @spec listen(:inet.port_number | Keyword.t) :: { :ok, t } | { :error, Socket.Error.t }
  def listen(port) when port |> is_integer do
    listen(port, [])
  end

  def listen(options) when options |> is_list do
    listen(0, options)
  end

  @doc """
  Create a TCP socket listening on an OS chosen port using the given options or
  listening on the given port, raising in case of error.
  """
  @spec listen!(:inet.port_number | Keyword.t) :: t | no_return
  defbang listen(port_or_options)

  @doc """
  Create a TCP socket listening on the given port and using the given options.
  """
  @spec listen(:inet.port_number, Keyword.t) :: { :ok, t } | { :error, Socket.Error.t }
  def listen(port, options) when options |> is_list do
    options = Keyword.put(options, :mode, :passive)
    options = Keyword.put_new(options, :reuseaddr, true)

    :gen_tcp.listen(port, arguments(options))
  end

  @doc """
  Create a TCP socket listening on the given port and using the given options,
  raising in case of error.
  """
  @spec listen!(:inet.port_number, Keyword.t) :: t | no_return
  defbang listen(port, options)

  @doc """
  Accept a new client from a listening socket, optionally passing options.
  """
  @spec accept(t | port)            :: { :ok, t } | { :error, Error.t }
  @spec accept(t | port, Keyword.t) :: { :ok, t } | { :error, Error.t }
  def accept(sock, options \\ []) do
    case :gen_tcp.accept(sock, options[:timeout] || :infinity) do
      { :ok, sock } ->
        case options[:mode] do
          :active ->
            :inet.setopts(sock, active: true)

          :once ->
            :inet.setopts(sock, active: :once)

          :passive ->
            :inet.setopts(sock, active: false)

          nil ->
            :ok
        end

        { :ok, sock }

      error ->
        error
    end
  end

  @doc """
  Accept a new client from a listening socket, optionally passing options,
  raising if an error occurs.
  """
  @spec accept!(t)            :: t | no_return
  @spec accept!(t, Keyword.t) :: t | no_return
  defbang accept(self)
  defbang accept(self, options)

  @doc """
  Set the process which will receive the messages.
  """
  @spec process(t, pid) :: :ok | { :error, :closed | :not_owner | Error.t }
  def process(sock, pid) do
    :gen_tcp.controlling_process(sock, pid)
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
  @spec options(t | Socket.SSL.t | port, Keyword.t) :: :ok | { :error, Socket.Error.t }
  def options(socket, options) when socket |> Record.record?(:sslsocket) do
    Socket.SSL.options(socket, options)
  end

  def options(socket, options) when socket |> is_port do
    :inet.setopts(socket, arguments(options))
  end

  @doc """
  Set options of the socket, raising if an error occurs.
  """
  @spec options!(t | Socket.SSL.t | port, Keyword.t) :: :ok | no_return
  defbang options(socket, options)

  @doc """
  Convert TCP options to `:inet.setopts` compatible arguments.
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

    if size = Keyword.get(options, :size) do
      args = [{ :packet_size, size } | args]
    end

    if packet = Keyword.get(options, :packet) do
      args = [{ :packet, packet } | args]
    end

    if backlog = Keyword.get(options, :backlog) do
      args = [{ :backlog, backlog } | args]
    end

    if watermark = Keyword.get(options, :watermark) do
      if low = Keyword.get(watermark, :low) do
        args = [{ :low_watermark, low } | args]
      end

      if high = Keyword.get(watermark, :high) do
        args = [{ :high_watermark, high } | args]
      end
    end

    if local = Keyword.get(options, :local) do
      if address = Keyword.get(local, :address) do
        args = [{ :ip, Socket.Address.parse(address) } | args]
      end

      if port = Keyword.get(local, :port) do
        args = [{ :port, port } | args]
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

    if opts = Keyword.get(options, :options) do
      if List.member?(opts, :keepalive) do
        args = [{ :keepalive, true } | args]
      end

      if List.member?(opts, :nodelay) do
        args = [{ :nodelay, true } | args]
      end
    end

    args
  end
end
