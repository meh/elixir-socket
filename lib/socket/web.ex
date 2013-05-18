defmodule Socket.Web do
  use    Bitwise
  import Kernel, except: [length: 1]

  @type t :: record

  defrecordp :web, socket: nil, path: nil, version: nil, origin: nil, key: nil, mask: nil

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

  def local(web(socket: sock)) do
    sock.local
  end

  def local!(web(socket: socket)) do
    socket.local!
  end

  def remote(web(socket: socket)) do
    socket.remote
  end

  def remote!(web(socket: socket)) do
    socket.remote!
  end

  Enum.each [ text: 0x1, binary: 0x2, close: 0x8, ping: 0x9, pong: 0xA ], fn { name, code } ->
    defp :opcode, [name], [], do: code
    defp :opcode, [code], [], do: name
  end

  Enum.each [ normal: 1000, going_away: 1001, protocol_error: 1002, unsupported_data: 1003,
              reserved: 1004, no_status_received: 1005, abnormal: 1006, invalid_payload: 1007,
              policy_violation: 1008, message_too_big: 1009, mandatory_extension: 1010,
              internal_error: 1011, handshake: 1015 ], fn { name, code } ->
    defp :close_code, [name], [], do: code
    defp :close_code, [code], [], do: name
  end

  defmacrop known?(n) do
    quote do
      unquote(n) in [0x1, 0x2, 0x8, 0x9, 0xA]
    end
  end

  defmacrop data?(n) do
    quote do
      unquote(n) in 0x1 .. 0x7 or unquote(n) in [:text, :binary]
    end
  end

  defmacrop control?(n) do
    quote do
      unquote(n) in 0x8 .. 0xF or unquote(n) in [:close, :ping, :pong]
    end
  end

  defp mask(data) do
    case :crypto.strong_rand_bytes(4) do
      << key :: 32 >> ->
        { key, unmask(key, data) }
    end
  end

  defp mask(key, data) do
    { key, unmask(key, data) }
  end

  defp unmask(key, data) do
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
                length :: 7 >> } when known?(opcode) and data?(opcode) ->
        case on_success { opcode(opcode), data } do
          { :ok, { :text, data } } = result ->
            if String.valid?(data) do
              result
            else
              { :error, :invalid_payload }
            end

          { :ok, { :binary, _ } } = result ->
            result
        end

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
                length :: 7 >> } when known?(opcode) and control?(opcode) ->
        on_success case opcode(opcode), do: (
          :ping -> { :ping, data }
          :pong -> { :pong, data }

          :close -> case data do
            <<>> ->
              :close

            << code :: 16, rest :: binary >> ->
              { :close, close_code(code), rest }
          end)

      { :ok, _ } ->
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
        raise RuntimeError, message: "protocol error"

      { :error, code } ->
        raise Socket.Error, code: code
    end
  end

  defp length(data) when byte_size(data) <= 125 do
    << byte_size(data) :: 7 >>
  end

  defp length(data) when byte_size(data) <= 65536 do
    << 126 :: 7, byte_size(data) :: 16 >>
  end

  defp length(data) when byte_size(data) <= 18446744073709551616 do
    << 127 :: 7, byte_size(data) :: 64 >>
  end

  defp forge(nil, data) do
    << 0 :: 1, length(data) :: bitstring, data :: bitstring >>
  end

  defp forge(true, data) do
    { key, data } = mask(data)

    << 1 :: 1, length(data) :: bitstring, key :: 32, data :: bitstring >>
  end

  defp forge(key, data) do
    { key, data } = mask(key, data)

    << 1 :: 1, length(data) :: bitstring, key :: 32, data :: bitstring >>
  end

  def send(packet, options // [], self)

  def send({ opcode, data }, options, web(socket: socket, version: 13, mask: mask)) when data?(opcode) and opcode != :close do
    socket.send(<< 1              :: 1,
                   0              :: 3,
                   opcode(opcode) :: 4,
                   forge(options[:mask] || mask, data) :: binary >>)
  end

  def send({ :fragmented, :end, data }, options, web(socket: socket, version: 13, mask: mask)) do
    socket.send(<< 1 :: 1,
                   0 :: 3,
                   0 :: 4,
                   forge(options[:mask] || mask, data) :: binary >>)
  end

  def send({ :fragmented, :continuation, data }, options, web(socket: socket, version: 13, mask: mask)) do
    socket.send(<< 0 :: 1,
                   0 :: 3,
                   0 :: 4,
                   forge(options[:mask] || mask, data) :: binary >>)
  end

  def send({ :fragmented, opcode, data }, options, web(socket: socket, version: 13, mask: mask)) do
    socket.send(<< 0              :: 1,
                   0              :: 3,
                   opcode(opcode) :: 4,
                   forge(options[:mask] || mask, data) :: binary >>)
  end

  def send!(packet, options // [], self) do
    case send(packet, options, self) do
      :ok ->
        :ok

      { :error, code } ->
        raise Socket.Error, code: code
    end
  end

  def ping(cookie // :crypt.rand_bytes(32), self) do
    case send({ :ping, cookie }, self) do
      :ok ->
        cookie

      { :error, _ } = error ->
        error
    end
  end

  def ping!(cookie // :crypt.rand_bytes(32), self) do
    send!({ :ping, cookie }, self)

    cookie
  end

  def pong(cookie, self) do
    send({ :pong, cookie }, self)
  end

  def pong!(cookie, self) do
    send!({ :pong, cookie }, self)
  end

  def close(web(socket: socket, version: 13)) do
    socket.send(<< 1              :: 1,
                   0              :: 3,
                   opcode(:close) :: 4,
                   forge(nil, <<>>) :: binary >>)
  end

  def close(reason, options // [], web(socket: socket, version: 13, mask: mask) = self) do
    if is_tuple(reason) do
      { reason, data } = reason
    else
      data = <<>>
    end

    socket.send(<< 1              :: 1,
                   0              :: 3,
                   opcode(:close) :: 4,
                   forge(options[:mask] || mask,
                     << close_code(reason) :: 16, data :: binary >>) :: binary >>)

    unless options[:wait] == false do
      do_close(self.recv, self)
    end
  end

  defp do_close({ :ok, :close }, self) do
    self.abort
  end

  defp do_close({ :ok, { :close, _, _ } }, self) do
    self.abort
  end

  defp do_close(_, self) do
    do_close(self.recv, self)
  end

  def abort(web(socket: socket)) do
    socket.close
  end
end
