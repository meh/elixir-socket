#            DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE
#                    Version 2, December 2004
#
#            DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE
#   TERMS AND CONDITIONS FOR COPYING, DISTRIBUTION AND MODIFICATION
#
#  0. You just DO WHAT THE FUCK YOU WANT TO.

defmodule Socket.Web do
  @moduledoc %S"""
  This module implements RFC 6455 WebSockets.

  ## Examples

      {:ok, sock} = Socket.Web.connect("echo.websocket.org")
      sock.send({:text, "hello there"}) # you can also send binary using {:binary, "hello there"})
      {:ok, data} = sock.recv
      IO.inspect data

  """

  use    Bitwise
  import Kernel, except: [length: 1, send: 2]

  @type t :: record

  @type error :: Socket.TCP.error | Socket.SSL.error

  @type packet :: { :text, String.t } |
                  { :binary, binary } |
                  { :fragmented, :text | :binary | :continuation | :end, binary } |
                  :close |
                  { :close, atom, binary } |
                  { :ping, binary } |
                  { :pong, binary }

  @compile { :inline, opcode: 1, close_code: 1, key: 1, error: 1, length: 1, forge: 2 }

  Enum.each [ text: 0x1, binary: 0x2, close: 0x8, ping: 0x9, pong: 0xA ], fn { name, code } ->
    defp opcode(unquote(name)), do: unquote(code)
    defp opcode(unquote(code)), do: unquote(name)
  end

  Enum.each [ normal: 1000, going_away: 1001, protocol_error: 1002, unsupported_data: 1003,
              reserved: 1004, no_status_received: 1005, abnormal: 1006, invalid_payload: 1007,
              policy_violation: 1008, message_too_big: 1009, mandatory_extension: 1010,
              internal_error: 1011, handshake: 1015 ], fn { name, code } ->
    defp close_code(unquote(name)), do: unquote(code)
    defp close_code(unquote(code)), do: unquote(name)
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

  defrecordp :web, __MODULE__, socket: nil, version: nil, path: nil, origin: nil, protocols: nil, extensions: nil, key: nil, mask: nil

  @spec headers([{ name :: String.t, value :: String.t }], Socket.t) :: [{ name :: String.t, value :: String.t }]
  defp headers(acc, socket) do
    case socket.recv! do
      { :http_header, _, name, _, value } when is_atom name ->
        [{ atom_to_binary(name) |> String.downcase, value } | acc] |> headers(socket)

      { :http_header, _, name, _, value } when is_binary name ->
        [{ String.downcase(name), value } | acc] |> headers(socket)

      :http_eoh ->
        acc
    end
  end

  @spec key(String.t) :: String.t
  defp key(value) do
    :crypto.hash(:sha, value <> "258EAFA5-E914-47DA-95CA-C5AB0DC85B11") |> :base64.encode
  end

  @spec error(t) :: module
  defp error(web(socket: socket)) do
    Module.concat(elem(socket, 0), Error)
  end

  @doc """
  Connects to the given address or { address, port } tuple.
  """
  @spec connect({ Socket.Address.t, :inet.port_number }) :: { :ok, t } | { :error, error }
  def connect({ address, port }) do
    connect(address, port, [])
  end

  def connect(address) do
    connect(address, [])
  end

  @doc """
  Connect to the given address or { address, port } tuple with the given
  options or address and port.
  """
  @spec connect({ Socket.Address.t, :inet.port_number } | Socket.Address.t, Keyword.t | :inet.port_number) :: { :ok, t } | { :error, error }
  def connect({ address, port }, options) do
    connect(address, port, options)
  end

  def connect(address, options) when is_list(options) do
    connect(address, if(options[:secure], do: 443, else: 80), options)
  end

  def connect(address, port) when is_integer(port) do
    connect(address, port, [])
  end

  @doc """
  Connect to the given address, port and options.

  ## Options

  `:path` sets the path to give the server, `/` by default
  `:origin` sets the Origin header, this is optional
  `:key` is the key used for the handshake, this is optional

  You can also pass TCP or SSL options, depending if you're using secure
  websockets or not.
  """
  @spec connect(Socket.Address.t, :inet.port_number, Keyword.t) :: { :ok, t } | { :error, error }
  def connect(address, port, options) do
    try do
      { :ok, connect!(address, port, options) }
    rescue
      MatchError ->
        { :error, "malformed handshake" }

      e in [RuntimeError] ->
        { :error, e.message }

      e in [Socket.TCP.Error, Socket.SSL.Error] ->
        { :error, e.code }
    end
  end

  @doc """
  Connects to the given address or { address, port } tuple, raising if an error
  occurs.
  """
  @spec connect!({ Socket.Address.t, :inet.port_number }) :: t | no_return
  def connect!({ address, port }) do
    connect!(address, port, [])
  end

  def connect!(address) do
    connect!(address, [])
  end

  @doc """
  Connect to the given address or { address, port } tuple with the given
  options or address and port, raising if an error occurs.
  """
  @spec connect!({ Socket.Address.t, :inet.port_number } | Socket.Address.t, Keyword.t | :inet.port_number) :: t | no_return
  def connect!({ address, port }, options) do
    connect!(address, port, options)
  end

  def connect!(address, options) when is_list(options) do
    connect!(address, if(options[:secure], do: 443, else: 80), options)
  end

  def connect!(address, port) when is_integer(port) do
    connect!(address, port, [])
  end

  @doc """
  Connect to the given address, port and options, raising if an error occurs.

  ## Options

  `:path` sets the path to give the server, `/` by default
  `:origin` sets the Origin header, this is optional
  `:key` is the key used for the handshake, this is optional

  You can also pass TCP or SSL options, depending if you're using secure
  websockets or not.
  """
  @spec connect!(Socket.Address.t, :inet.port_number, Keyword.t) :: t | no_return
  def connect!(address, port, options) do
    mod = if options[:secure] do
      Socket.SSL
    else
      Socket.TCP
    end

    path       = options[:path] || "/"
    origin     = options[:origin]
    protocols  = options[:protocol]
    extensions = options[:extensions]
    key        = :base64.encode(options[:key] || "fork the dongles")

    client = mod.connect!(address, port)
    client.packet!(:raw)
    client.send!([
      "GET #{path} HTTP/1.1", "\r\n",
      "Host: #{address}:#{port}", "\r\n",
      if(origin, do: ["Origin: #{origin}", "\r\n"], else: []),
      "Upgrade: websocket", "\r\n",
      "Connection: Upgrade", "\r\n",
      "Sec-WebSocket-Key: #{key}", "\r\n",
      if(protocols, do: ["Sec-WebSocket-Protocol: #{Enum.join protocols, ", "}", "\r\n"], else: []),
      if(extensions, do: ["Sec-WebSocket-Extensions: #{Enum.join extensions, ", "}", "\r\n"], else: []),
      "Sec-WebSocket-Version: 13", "\r\n",
      "\r\n"])

    client.packet(:http_bin)
    { :http_response, _, 101, _ } = client.recv!
    headers                       = headers([], client)

    if String.downcase(headers["upgrade"]) != "websocket" or
       String.downcase(headers["connection"]) != "upgrade" do
      client.close

      raise RuntimeError, message: "malformed upgrade response"
    end

    if headers["sec-websocket-version"] && headers["sec-websocket-version"] != "13" do
      client.close

      raise RuntimeError, message: "unsupported version"
    end

    if !headers["sec-websocket-accept"] or headers["sec-websocket-accept"] != key(key) do
      client.close

      raise RuntimeError, message: "wrong key response"
    end

    client.packet!(:raw)

    web(socket: client, version: 13, path: path, origin: origin, key: key, mask: true)
  end

  @doc """
  Listens on the default port (80).
  """
  @spec listen :: { :ok, t } | { :error, error }
  def listen do
    listen([])
  end

  @doc """
  Listens on the given port or with the given options.
  """
  @spec listen(:inet.port_number | Keyword.t) :: { :ok, t } | { :error, error }
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

  @doc """
  Listens on the given port with the given options.

  ## Options

  `:secure` when true it will use SSL sockets

  You can also pass TCP or SSL options, depending if you're using secure
  websockets or not.
  """
  @spec listen(:inet.port_number, Keyword.t) :: { :ok, t } | { :error, error }
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

  @doc """
  Listens on the default port (80), raising if an error occurs.
  """
  @spec listen! :: t | no_return
  def listen! do
    listen!([])
  end

  @doc """
  Listens on the given port or with the given options, raising if an error
  occurs.
  """
  @spec listen!(:inet.port_number | Keyword.t) :: t | no_return
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

  @doc """
  Listens on the given port with the given options, raising if an error occurs.

  ## Options

  `:secure` when true it will use SSL sockets

  You can also pass TCP or SSL options, depending if you're using secure
  websockets or not.
  """
  @spec listen!(:inet.port_number, Keyword.t) :: t | no_return
  def listen!(port, options) do
    mod = if options[:secure] do
      Socket.SSL
    else
      Socket.TCP
    end

    web(socket: mod.listen!(port, options))
  end

  @doc """
  If you're calling this on a listening socket, it accepts a new client
  connection.

  If you're calling this on a client socket, it finalizes the acception
  handshake, this separation is done because then you can verify the client can
  connect based on Origin header, path and other things.
  """
  @spec accept(t) :: { :ok, t } | { :error, error }
  def accept(web(key: nil) = self) do
    accept([], self)
  end

  def accept(web() = self) do
    try do
      { :ok, accept!(self) }
    rescue
      e in [Socket.TCP.Error, Socket.SSL.Error] ->
        { :error, e.code }
    end
  end

  @doc """
  Accept a client connection from the listening socket with the passed options.
  """
  @spec accept(Keyword.t, t) :: { :ok, t } | { :error, error }
  def accept(options, web(key: nil) = self) do
    try do
      { :ok, accept!(options, self) }
    rescue
      MatchError ->
        { :error, "malformed handshake" }

      e in [RuntimeError] ->
        { :error, e.message }

      e in [Socket.TCP.Error, Socket.SSL.Error] ->
        { :error, e.code }
    end
  end

  @doc """
  If you're calling this on a listening socket, it accepts a new client
  connection.

  If you're calling this on a client socket, it finalizes the acception
  handshake, this separation is done because then you can verify the client can
  connect based on Origin header, path and other things.

  In case of error, it raises.
  """
  @spec accept!(t) :: t | no_return
  def accept!(self) do
    accept!([], self)
  end

  @doc """
  Accept a client connection from the listening socket with the passed options,
  raising if an error occurs.
  """
  @spec accept!(Keyword.t, t) :: t | no_return
  def accept!(options, web(socket: socket, key: nil)) do
    client = socket.accept!(options)
    client.packet!(:http_bin)

    path = case client.recv! do
      { :http_request, :GET, { :abs_path, path }, _ } ->
        path
    end

    headers = headers([], client)

    if headers["upgrade"] != "websocket" or headers["connection"] != "Upgrade" do
      client.close

      raise RuntimeError, message: "malformed upgrade request"
    end

    unless headers["sec-websocket-key"] do
      client.close

      raise RuntimeError, message: "missing key"
    end

    protocols = if p = headers["sec-websocket-protocol"] do
      String.split(p, %r/\s*,\s*/)
    end

    extensions = if e = headers["sec-websocket-extensions"] do
      String.split(e, %r/\s*,\s*/)
    end

    client.packet!(:raw)

    web(socket: client,
        origin: headers["origin"],
        path: path,
        version: 13,
        key: headers["sec-websocket-key"],
        protocols: protocols,
        extensions: extensions)
  end

  def accept!(options, web(socket: socket, key: key)) do
    extensions = options[:extension]
    protocol   = options[:protocol]

    socket.packet(:raw)
    socket.send!([
      "HTTP/1.1 101 Switching Protocols", "\r\n",
      "Upgrade: websocket", "\r\n",
      "Connection: Upgrade", "\r\n",
      "Sec-WebSocket-Accept: #{key(key)}", "\r\n",
      "Sec-WebSocket-Version: 13", "\r\n",
      if(extensions, do: ["Sec-WebSocket-Extensions: ", Enum.join(extensions, ", "), "\r\n"], else: []),
      if(protocol, do: ["Sec-WebSocket-Protocol: ", protocol, "\r\n"], else: []),
      "\r\n"])
  end

  @doc """
  Return the local address and port.
  """
  @spec local(t) :: { :ok, { :inet.ip_address, :inet.port_number } } | { :error, error }
  def local(web(socket: sock)) do
    sock.local
  end

  @doc """
  Return the local address and port, raising if an error occurs.
  """
  @spec local!(t) :: { :inet.ip_address, :inet.port_number } | no_return
  def local!(web(socket: socket)) do
    socket.local!
  end

  @doc """
  Return the remote address and port.
  """
  @spec remote(t) :: { :ok, { :inet.ip_address, :inet.port_number } } | { :error, error }
  def remote(web(socket: socket)) do
    socket.remote
  end

  @doc """
  Return the remote address and port, raising if an error occurs.
  """
  @spec remote!(t) :: { :inet.ip_address, :inet.port_number } | no_return
  def remote!(web(socket: socket)) do
    socket.remote!
  end

  @spec mask(binary) :: { integer, binary }
  defp mask(data) do
    case :crypto.strong_rand_bytes(4) do
      << key :: 32 >> ->
        { key, unmask(key, data) }
    end
  end

  @spec mask(integer, binary) :: { integer, binary }
  defp mask(key, data) do
    { key, unmask(key, data) }
  end

  @spec unmask(integer, binary) :: binary
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

  @spec recv(boolean, non_neg_integer, t) :: { :ok, binary } | { :error, error }
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
      case recv(var!(mask) == 1, var!(length), var!(self)) do
        { :ok, var!(data) } ->
          { :ok, unquote(result) }

        { :error, _ } = error ->
          error
      end
    end
  end

  @doc """
  Receive a packet from the websocket.
  """
  @spec recv(t) :: { :ok, packet } | { :error, error }
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

  @doc """
  Receive a packet from the websocket, raising if an error occurs.
  """
  @spec recv!(t) :: packet | no_return
  def recv!(self) do
    case recv(self) do
      { :ok, packet } ->
        packet

      { :error, :protocol_error } ->
        raise RuntimeError, message: "protocol error"

      { :error, code } ->
        raise error(self), code: code
    end
  end

  @spec length(binary) :: binary
  defp length(data) when byte_size(data) <= 125 do
    << byte_size(data) :: 7 >>
  end

  defp length(data) when byte_size(data) <= 65536 do
    << 126 :: 7, byte_size(data) :: 16 >>
  end

  defp length(data) when byte_size(data) <= 18446744073709551616 do
    << 127 :: 7, byte_size(data) :: 64 >>
  end

  @spec forge(nil | true | integer, binary) :: binary
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

  @doc """
  Send a packet to the websocket.
  """
  @spec send(packet, t)            :: :ok | { :error, error }
  @spec send(packet, Keyword.t, t) :: :ok | { :error, error }
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

  @doc """
  Send a packet to the websocket, raising if an error occurs.
  """
  @spec send!(packet, t)            :: :ok | no_return
  @spec send!(packet, Keyword.t, t) :: :ok | no_return
  def send!(packet, options // [], self) do
    case send(packet, options, self) do
      :ok ->
        :ok

      { :error, code } ->
        raise error(self), code: code
    end
  end

  @doc """
  Send a ping request with the optional cookie.
  """
  @spec ping(t)         :: :ok | { :error, error }
  @spec ping(binary, t) :: :ok | { :error, error }
  def ping(cookie // :crypt.rand_bytes(32), self) do
    case send({ :ping, cookie }, self) do
      :ok ->
        cookie

      { :error, _ } = error ->
        error
    end
  end

  @doc """
  Send a ping request with the optional cookie, raising if an error occurs.
  """
  @spec ping!(t)         :: :ok | no_return
  @spec ping!(binary, t) :: :ok | no_return
  def ping!(cookie // :crypt.rand_bytes(32), self) do
    send!({ :ping, cookie }, self)

    cookie
  end

  @doc """
  Send a pong with the given (and received) ping cookie.
  """
  @spec pong(binary, t) :: :ok | { :error, error }
  def pong(cookie, self) do
    send({ :pong, cookie }, self)
  end

  @doc """
  Send a pong with the given (and received) ping cookie, raising if an error
  occurs.
  """
  @spec pong!(binary, t) :: :ok | no_return
  def pong!(cookie, self) do
    send!({ :pong, cookie }, self)
  end

  @doc """
  Close the socket when a close request has been received.
  """
  @spec close(t) :: :ok | { :error, error }
  def close(web(socket: socket, version: 13)) do
    socket.send(<< 1              :: 1,
                   0              :: 3,
                   opcode(:close) :: 4,

                   forge(nil, <<>>) :: binary >>)
  end

  @doc """
  Close the socket sending a close request, unless `:wait` is set to `false` it
  blocks until the close response has been received, and then closes the
  underlying socket.
  """
  @spec close(atom, Keyword.t, t) :: :ok | { :error, error }
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

  @doc """
  Close the underlying socket, only use when you mean it, normal closure
  procedure should be preferred.
  """
  @spec abort(t) :: :ok | { :error, error }
  def abort(web(socket: socket)) do
    socket.close
  end
end
