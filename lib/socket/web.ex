defmodule Socket.Web do
  use Bitwise

  defrecordp :web, socket: nil, path: nil, version: nil, origin: nil, key: nil

  def listen do
    listen([])
  end

  def listen(port) when is_integer(port) do
    listen(port, [])
  end

  def listen(options) do
    if listen[:secure] do
      listen(443, options)
    else
      listen(80, options)
    end
  end

  def listen(port, options) do
    mod = if options[:secure] do
      Socket.SSL
    else
      Socket.TCP
    end

    case mod.listen(port, options) do
      { :ok, socket } ->
        { :ok, web(socket: socket) }

      error ->
        error
    end
  end

  def listen! do
    listen!([])
  end

  def listen!(port) when is_integer(port) do
    listen!(port, [])
  end

  def listen!(options) do
    if listen[:secure] do
      listen!(443, options)
    else
      listen!(80, options)
    end
  end

  def listen!(port, options) do
    web(socket: Socket.TCP.listen!(port, options))
  end

  def accept(options // [], self) do
    try do
      { :ok, accept!(options, self) }
    rescue
      MatchError ->
        { :error, "malformed handshake" }

      RuntimeError[message: msg] ->
        { :error, msg }

      Socket.Error[code: code] ->
        { :error, code }
    end
  end

  defp headers(acc, socket) do
    case socket.recv! do
      "\r\n" ->
        acc

      line ->
        [_, name, value] = Regex.run %r/^(.*?):\s*(.*?)\s*$/, line

        headers([{ String.downcase(name), value } | acc], socket)
    end
  end

  defp key(value) do
    :base64.encode(:crypto.sha(value <> "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"))
  end

  def accept!(options // [], web(socket: socket)) do
    client = socket.accept!
    client.options!(packet: :line)

    [_, path] = Regex.run %r"^GET (/.*?) HTTP/1.1", client.recv!
    headers   = headers([], client)

    if headers["upgrade"] != "websocket" or headers["connection"] != "Upgrade" do
      client.close

      raise RuntimeError, message: "malformed upgrade request"
    end

    unless headers["sec-websocket-key"] do
      client.close

      raise RuntimeError, message: "missing key"
    end

    socket = web(socket: client,
      origin: headers["origin"], path: path, version: 13, key: headers["sec-websocket-key"])

    if options[:verify] && !options[:verify].(socket) do
      client.close

      raise RuntimeError, message: "verification failed"
    end

    client.options!(packet: :raw)
    client.send!([
      "HTTP/1.1 101 Switching Protocols", "\r\n",
      "Upgrade: websocket", "\r\n",
      "Connection: Upgrade", "\r\n",
      "Sec-WebSocket-Accept: #{key(web(socket, :key))}", "\r\n",
      "Sec-WebSocket-Protocol: chat", "\r\n",
      "\r\n"])

    socket
  end

  defp opcode(0x1), do: :text
  defp opcode(0x2), do: :binary
  defp opcode(0x8), do: :close
  defp opcode(0x9), do: :ping
  defp opcode(0xA), do: :pong

  defp opcode(:text),   do: 0x1
  defp opcode(:binary), do: 0x2
  defp opcode(:close),  do: 0x8
  defp opcode(:ping),   do: 0x9
  defp opcode(:pong),   do: 0xA

  defmacrop known?(n) do
    quote do
      unquote(n) in [0x1, 0x2, 0x8, 0x9, 0xA]
    end
  end

  defmacrop data?(n) do
    quote do
      unquote(n) in 0x1 .. 0x7
    end
  end

  defmacrop control?(n) do
    quote do
      unquote(n) in 0x8 .. 0xF
    end
  end

  defp unmask(key, data) do
    unmask(key, data, <<>>)
  end

  defp mask(key, data) do
    unmask(key, data, <<>>)
  end

  # we have to XOR the key with the data iterating over the key when there's
  # more data, this means we can optimize and do it 4 bytes at a time and then
  # fallback to the smaller sizes
  defp unmask(key, << data :: 32, rest :: binary >>, acc) do
    unmask(key, rest, << acc :: binary, data ^^^ key :: 32 >>)
  end

  defp unmask(key, << data :: 24 >>, acc) do
    << key :: 24, _ :: 8 >> = << key :: 32 >>

    unmask(key, <<>>, << acc :: binary, data ^^^ key :: 24 >>)
  end

  defp unmask(key, << data :: 16 >>, acc) do
    << key :: 16, _ :: 16 >> = << key :: 32 >>

    unmask(key, <<>>, << acc :: binary, data ^^^ key :: 16 >>)
  end

  defp unmask(key, << data :: 8 >>, acc) do
    << key :: 8, _ :: 24 >> = << key :: 32 >>

    unmask(key, <<>>, << acc :: binary, data ^^^ key :: 8 >>)
  end

  defp unmask(_, <<>>, acc) do
    acc
  end

  defp recv(mask, length, web(socket: socket, version: 13)) do
    length = cond do
      length == 127 ->
        case socket.recv(8) do
          { :ok, << length :: 64 >> } ->
            length

          { :error, _ } = error ->
            error
        end

      length == 126 ->
        case socket.recv(2) do
          { :ok, << length :: 16 >> } ->
            length

          { :error, _ } = error ->
            error
        end

      length <= 125 ->
        length
    end

    case length do
      { :error, _ } = error ->
        error

      length ->
        if mask do
          case socket.recv(4) do
            { :ok, << key :: 32 >> } ->
              case socket.recv(length) do
                { :ok, data } ->
                  { :ok, unmask(key, data) }

                { :error, _ } = error ->
                  error
              end

            { :error, _ } = error ->
              error
          end
        else
          case socket.recv(length) do
            { :ok, data } ->
              { :ok, data }

            { :error, _ } = error ->
              error
          end
        end
    end
  end

  defmacrop on_success(result) do
    quote do
      case recv(var!(mask), var!(length), var!(self)) do
        { :ok, var!(data) } ->
          { :ok, unquote(result) }

        { :error, _ } = error ->
          error
      end
    end
  end

  def recv(web(socket: socket, version: 13) = self) do
    case socket.recv(2) do
      # a non fragmented message packet
      { :ok, << 1      :: 1,
                0      :: 3,
                opcode :: 4,
                mask   :: 1,
                length :: 7 >> } when known?(opcode) and not control?(opcode) ->
        on_success { opcode(opcode), data }

      # beginning of a fragmented packet
      { :ok, << 0      :: 1,
                0      :: 3,
                opcode :: 4,
                mask   :: 1,
                length :: 7 >> } when known?(opcode) and not control?(opcode) ->
        on_success { :fragmented, opcode(opcode), data }

      # a fragmented continuation
      { :ok, << 0      :: 1,
                0      :: 3,
                0      :: 4,
                mask   :: 1,
                length :: 7 >> } ->
        on_success { :fragmented, :continuation, data }

      # final fragmented packet
      { :ok, << 1      :: 1,
                0      :: 3,
                0      :: 4,
                mask   :: 1,
                length :: 7 >> } ->
        on_success { :fragmented, :end, data }

      # control packet
      { :ok, << 1      :: 1,
                0      :: 3,
                opcode :: 4,
                mask   :: 1,
                length :: 7 >> } when known?(opcode) and control?(opcode) and length <= 125 ->
        on_success { opcode(opcode), data }

      { :ok, _ } ->
        close(:protocol_error)

        { :error, :protocol_error }

      { :error, _ } = error ->
        error
    end
  end

  def recv!(self) do
    case recv(self) do
      { :ok, packet } ->
        packet

      { :error, :protocol_error } ->
        raise RuntimeErrror, message: "protocol error"

      { :error, code } ->
        raise Socket.Error, code: code
    end
  end

  def send(packet, options // [], web(socket: socket, version: 13)) do

  end

  def close(reason // nil, web(socket: socket, version: 13) = self) do
  end
end
