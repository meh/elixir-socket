defmodule Socket.TCP do
  defrecordp :socket, port: nil, reference: nil

  defp arguments(options) do
    args = Socket.arguments(options)
    args = [{ :active, false } | args]

    args = case options[:as] || :binary do
      :list   -> [:list | args]
      :binary -> [:binary | args]
    end

    if options[:size] do
      args = [{ :packet_size, options[:size] } | args]
    end

    if options[:packet] do
      args = [{ :packet, options[:packet] } | args]
    end

    if watermark = options[:watermark] do
      if watermark[:low] do
        args = [{ :low_watermark, watermark[:low] } | args]
      end

      if watermark[:high] do
        args = [{ :high_watermark, watermark[:high] } | args]
      end
    end

    if local = options[:local] do
      if local[:address] do
        args = [{ :ip, binary_to_list(local[:address]) } | args]
      end

      if local[:port] do
        args = [{ :port, local[:port] } | args]
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

  def connect(address, port, options // []) do
    if is_binary(address) do
      address = binary_to_list(address)
    end

    case :gen_tcp.connect(address, port, arguments(options)) do
      { :ok, sock } ->
        reference = if options[:automatic] != false do
          :gen_tcp.controlling_process(sock, Process.whereis(Socket.Manager))
          Finalizer.define({ :close, sock }, Process.whereis(Socket.Manager))
        end

        { :ok, socket(port: sock, reference: reference) }

      error ->
        error
    end
  end

  def connect!(address, port, options // []) do
    case connect(address, port, options) do
      { :ok, socket } ->
        socket

      { :error, code } ->
        raise Socket.Error, code: code
    end
  end

  def listen do
    listen(0, [])
  end

  def listen(port) when is_integer(port) do
    listen(port, [])
  end

  def listen(options) do
    listen(0, options)
  end

  def listen(port, options) do
    args = arguments(options)

    case :gen_tcp.listen(port, args) do
      { :ok, sock } ->
        reference = if options[:automatic] != false do
          :gen_tcp.controlling_process(sock, Process.whereis(Socket.Manager))
          Finalizer.define({ :close, sock }, Process.whereis(Socket.Manager))
        end

        { :ok, socket(port: sock, reference: reference) }

      error -> error
    end
  end

  def listen! do
    listen!(0, [])
  end

  def listen!(port) when is_integer(port) do
    listen!(port, [])
  end

  def listen!(options) do
    listen!(0, options)
  end

  def listen!(port, options) do
    case listen(port, options) do
      { :ok, socket } ->
        socket

      { :error, code } ->
        raise Socket.Error, code: code
    end
  end

  def accept(timeout // :infinity, socket(port: sock, reference: ref)) do
    case :gen_tcp.accept(sock, timeout) do
      { :ok, sock } ->
        { :ok, socket(port: sock, reference: if(ref, do: (
          :gen_tcp.controlling_process(sock, Process.whereis(Socket.Manager))
          Finalizer.define({ :close, sock }, Process.whereis(Socket.Manager))))) }

      error -> error
    end
  end

  def accept!(timeout // :infinity, self) do
    case accept(timeout, self) do
      { :ok, socket } ->
        socket

      { :error, code } ->
        raise Socket.Error, code: code
    end
  end

  def local(socket(port: port)) do
    :inet.sockname(port)
  end

  def local!(socket(port: port)) do
    case :inet.sockname(port) do
      { :ok, result } ->
        result

      { :error, code } ->
        raise Socket.Error, code: code
    end
  end

  def remote(socket(port: port)) do
    :inet.peername(port)
  end

  def remote!(socket(port: port)) do
    case :inet.peername(port) do
      { :ok, result } ->
        result

      { :error, code } ->
        raise Socket.Error, code: code
    end
  end

  def send(value, socket(port: port)) do
    :gen_tcp.send(port, to_binary(value))
  end

  def send!(value, self) do
    case send(value, self) do
      :ok ->
        :ok

      { :error, code } ->
        raise Socket.Error, code: code
    end
  end

  def recv(socket(port: port)) do
    :gen_tcp.recv(port, 0)
  end

  def recv(length, socket(port: port)) when is_integer(length) do
    :gen_tcp.recv(port, length)
  end

  def recv(options, self) do
    recv(0, options, self)
  end

  def recv(length, options, socket(port: port)) do
    if timeout = options[:timeout] do
      :gen_tcp.recv(port, length, timeout)
    else
      :gen_tcp.recv(port, length)
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

  def shutdown(how, socket(port: sock)) do
    :gen_tcp.shutdown(sock, how)
  end

  def close(socket(port: port)) do
    :gen_tcp.close(port)
  end
end
