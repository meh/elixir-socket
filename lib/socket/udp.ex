#            DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE
#                    Version 2, December 2004
#
#            DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE
#   TERMS AND CONDITIONS FOR COPYING, DISTRIBUTION AND MODIFICATION
#
#  0. You just DO WHAT THE FUCK YOU WANT TO.

defmodule Socket.UDP do
  @type t :: record

  defrecordp :socket, port: nil, reference: nil

  @doc """
  Create a UDP socket listening on an OS chosen port, use `local` to know the
  port it was bound on.
  """
  @spec open :: { :ok, t } | { :error, :inet.posix }
  def open do
    open(0, [])
  end

  @spec open(:inet.port_number | Keyword.t) :: { :ok, t } | { :error, :inet.posix }
  def open(port) when is_integer(port) do
    open(port, [])
  end

  def open(options) do
    open(0, options)
  end

  @spec open(:inet.port_number, Keyword.t) :: { :ok, t } | { :error, :inet.posix }
  def open(port, options) do
    case :gen_udp.open(port, arguments(options)) do
      { :ok, sock } ->
        reference = if options[:automatic] != false do
          :gen_udp.controlling_process(sock, Process.whereis(Socket.Manager))
          Finalizer.define({ :close, :udp, sock }, Process.whereis(Socket.Manager))
        end

        { :ok, socket(port: sock, reference: reference) }

      error ->
        error
    end
  end

  @spec open! :: t | no_return
  def open! do
    open!(0, [])
  end

  @spec open!(:inet.port_number | Keyword.t) :: t | no_return
  def open!(port) when is_integer(port) do
    open!(port, [])
  end

  def open!(options) do
    open!(0, options)
  end

  @spec open!(:ient.port_number, Keyword.t) :: t | no_return
  def open!(port, options) do
    case open(port, options) do
      { :ok, socket } ->
        socket

      { :error, code } ->
        raise Socket.Error, code: code
    end
  end

  @doc """
  Set options of the socket.
  """
  @spec options(Keyword.t, t) :: :ok | { :error, :inet.posix }
  def options(opts, socket(port: port)) do
    :inet.setopts(port, arguments(opts))
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
        raise Socket.Error, code: code
    end
  end

  @spec send(String.t | :inet.ip_address, :inet.port_number, iodata, t) :: :ok | { :error, :inet.posix }
  def send(address, port, value, socket(port: port)) do
    if is_binary(address) do
      address = binary_to_list(address)
    end

    :gen_udp.send(port, address, port, value)
  end

  @spec send(String.t | :inet.ip_address, :inet.port_number, iodata, t) :: :ok | no_return
  def send!(address, port, value, self) do
    case send(address, port, value, self) do
      :ok ->
        :ok

      { :error, code } ->
        raise Socket.Error, code: code
    end
  end

  @spec recv(t) :: { :ok, { :inet.ip_address, :inet.port_number, iodata } } | { :error, :inet.posix }
  def recv(socket(port: port)) do
    :gen_udp.recv(port, 512)
  end

  @spec recv(non_neg_integer | Keyword.t, t) :: { :ok, { :inet.ip_address, :inet.port_number, iodata } } | { :error, :inet.posix }
  def recv(length, socket(port: port)) when is_integer(length) do
    :gen_udp.recv(port, length)
  end

  def recv(options, self) do
    recv(512, options, self)
  end

  @spec recv(non_neg_integer, Keyword.t, t) :: { :ok, { :inet.ip_address, :inet.port_number, iodata } } | { :error, :inet.posix }
  def recv(length, options, socket(port: port)) do
    :gen_udp.recv(port, length, options[:timeout] || :infinity)
  end

  @spec recv!(t) :: { :inet.ip_address, :inet.port_number, iodata } | no_return
  def recv!(self) do
    case recv(self) do
      { :ok, packet } ->
        packet

      { :error, code } ->
        raise Socket.Error, code: code
    end
  end

  @spec recv!(non_neg_integer | Keyword.t, t) :: { :inet.ip_address, :inet.port_number, iodata } | no_return
  def recv!(length_or_options, self) do
    case recv(length_or_options, self) do
      { :ok, packet } ->
        packet

      { :error, code } ->
        raise Socket.Error, code: code
    end
  end

  @spec recv!(non_neg_integer, Keyword.t, t) :: { :inet.ip_address, :inet.port_number, iodata } | no_return
  def recv!(length, options, self) do
    case recv(length, options, self) do
      { :ok, packet } ->
        packet

      { :error, code } ->
        raise Socket.Error, code: code
    end
  end

  @spec close(t) :: :ok
  def close(socket(port: port)) do
    :gen_udp.close(port)
  end

  @spec to_port(t) :: port
  def to_port(socket(port: port)) do
    port
  end

  @doc """
  Convert UDP options to `:inet.setopts` compatible arguments.
  """
  @spec arguments(Keyword.t) :: list
  def arguments(options) do
    args = Socket.arguments(options)
    args = [{ :active, false } | args]

    args = case options[:as] || :binary do
      :list   -> [:list | args]
      :binary -> [:binary | args]
    end

    if local = options[:local] do
      if address = local[:address] do
        if is_binary(address) do
          address = binary_to_list(address)
        end

        args = [{ :ip, Socket.Address.parse(address) } | args]
      end

      if local[:fd] do
        args = [{ :fd, local[:fd] } | args]
      end
    end

    args = case options[:version] do
      4 -> [:inet | args]
      6 -> [:inet6 | args]

      nil -> args
    end

    if Keyword.has_key?(options, :broadcast) do
      args = [{ :broadcast, options[:broadcast] } | args]
    end

    if options[:options] do
      if List.member?(options[:options], :keepalive) do
        args = [{ :keepalive, true } | args]
      end

      if List.member?(options[:options], :nodelay) do
        args = [{ :nodelay, true } | args]
      end
    end

    args
  end
end
