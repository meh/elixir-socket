defmodule Socket.UDP do
  @type t :: record

  defrecordp :socket, port: nil, reference: nil

  def open do
    open(0, [])
  end

  def open(port) when is_integer(port) do
    open(port, [])
  end

  def open(options) do
    open(0, options)
  end

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

  def open! do
    open!(0, [])
  end

  def open!(port) when is_integer(port) do
    open!(port, [])
  end

  def open!(options) do
    open!(0, options)
  end

  def open!(port, options // []) do
    case open(port, options) do
      { :ok, socket } ->
        socket

      { :error, code } ->
        raise Socket.Error, code: code
    end
  end

  def send(address, port, value, socket(port: port)) do
    if is_binary(address) do
      address = binary_to_list(address)
    end

    :gen_udp.send(port, address, port, value)
  end

  def send!(address, port, value, self) do
    case send(address, port, value, self) do
      :ok ->
        :ok

      { :error, code } ->
        raise Socket.Error, code: code
    end
  end

  def recv(socket(port: port)) do
    :gen_udp.recv(port, 512)
  end

  def recv(length, socket(port: port)) when is_integer(length) do
    :gen_udp.recv(port, length)
  end

  def recv(options, self) do
    recv(512, options, self)
  end

  def recv(length, options, socket(port: port)) do
    if timeout = options[:timeout] do
      :gen_udp.recv(port, length, timeout)
    else
      :gen_udp.recv(port, length)
    end
  end

  def recv!(self) do
    case recv(self) do
      { :ok, packet } ->
        packet

      { :error, code } ->
        raise Socket.Error, code: code
    end
  end

  def recv!(length_or_options, self) do
    case recv(length_or_options, self) do
      { :ok, packet } ->
        packet

      { :error, code } ->
        raise Socket.Error, code: code
    end
  end

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

  defp arguments(options) do
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
