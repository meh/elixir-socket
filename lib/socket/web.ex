#            DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE
#                    Version 2, December 2004
#
#            DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE
#   TERMS AND CONDITIONS FOR COPYING, DISTRIBUTION AND MODIFICATION
#
#  0. You just DO WHAT THE FUCK YOU WANT TO.

defmodule Socket.Web do
  @moduledoc ~S"""
  This module implements RFC 6455 WebSockets.

  ## Client example

      socket = Socket.Web.connect! "echo.websocket.org"
      socket |> Socket.Web.send! { :text, "test" }
      socket |> Socket.Web.recv! # => {:text, "test"}

  ## Server example

      server = Socket.Web.listen! 80
      client = server |> Socket.Web.accept!

      # here you can verify if you want to accept the request or not, call
      # `Socket.Web.close!` if you don't want to accept it, or else call
      # `Socket.Web.accept!`
      client |> Socket.Web.accept!

      # echo the first message
      client |> Socket.Web.send!(client |> Socket.Web.recv!)

  """

  use    Bitwise
  import Kernel, except: [length: 1, send: 2]
  alias __MODULE__, as: W

  @type error :: Socket.TCP.error | Socket.SSL.error

  @type packet :: { :text, String.t } |
                  { :binary, binary } |
                  { :fragmented, :text | :binary | :continuation | :end, binary } |
                  :close |
                  { :close, atom, binary } |
                  { :ping, binary } |
                  { :pong, binary }

  @compile { :inline, opcode: 1, close_code: 1, key: 1, length: 1, forge: 2 }

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

  defstruct [:socket, :version, :path, :origin, :protocols, :extensions, :key, :mask, { :headers, %{} }]

  @type t :: %Socket.Web{
    socket:     term,
    version:    13,
    path:       String.t,
    origin:     String.t,
    protocols:  [String.t],
    extensions: [String.t],
    key:        String.t,
    mask:       boolean }

  @spec headers(%{String.t => String.t}, Socket.t, Keyword.t) :: %{String.t => String.t}
  defp headers(acc, socket, options) do
    case socket |> Socket.Stream.recv!(options) do
      { :http_header, _, name, _, value } when name |> is_atom ->
        acc |> Map.put(Atom.to_string(name) |> String.downcase, value) |> headers(socket, options)

      { :http_header, _, name, _, value } when name |> is_binary ->
        acc |> Map.put(String.downcase(name), value) |> headers(socket, options)

      :http_eoh ->
        acc
    end
  end

  @spec key(String.t) :: String.t
  defp key(value) do
    :crypto.hash(:sha, value <> "258EAFA5-E914-47DA-95CA-C5AB0DC85B11") |> :base64.encode
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

  def connect(address, options) when options |> is_list do
    connect(address, if(options[:secure], do: 443, else: 80), options)
  end

  def connect(address, port) when port |> is_integer do
    connect(address, port, [])
  end

  @doc """
  Connect to the given address, port and options.

  ## Options

  `:path` sets the path to give the server, `/` by default
  `:origin` sets the Origin header, this is optional
  `:handshake` is the key used for the handshake, this is optional

  You can also pass TCP or SSL options, depending if you're using secure
  websockets or not.
  """
  @spec connect(Socket.Address.t, :inet.port_number, Keyword.t) :: { :ok, t } | { :error, error }
  def connect(address, port, options) do
    try do
      { :ok, connect!(address, port, options) }
    rescue
      e in [MatchError] ->
        case e.term do
          { :http_response, _, http_code, http_message } -> { :error, { http_code, http_message } }
          _ -> { :error, "malformed handshake" }
        end

      e in [RuntimeError] ->
        { :error, e.message }

      e in [Socket.Error] ->
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

  def connect!(address, options) when options |> is_list do
    connect!(address, if(options[:secure], do: 443, else: 80), options)
  end

  def connect!(address, port) when port |> is_integer do
    connect!(address, port, [])
  end

  @doc """
  Connect to the given address, port and options, raising if an error occurs.

  ## Options

  `:path` sets the path to give the server, `/` by default
  `:origin` sets the Origin header, this is optional
  `:handshake` is the key used for the handshake, this is optional
  `:headers` are additional headers that will be sent

  You can also pass TCP or SSL options, depending if you're using secure
  websockets or not.
  """
  @spec connect!(Socket.Address.t, :inet.port_number, Keyword.t) :: t | no_return
  def connect!(address, port, options) do
    { local, global } = arguments(options)

    mod = if local[:secure] do
      Socket.SSL
    else
      Socket.TCP
    end

    path       = local[:path] || "/"
    origin     = local[:origin]
    protocols  = local[:protocol]
    extensions = local[:extensions]
    handshake  = :base64.encode(local[:handshake] || "fork the dongles")
    headers    = Enum.map(local[:headers] || %{}, fn({ k, v }) -> ["#{k}: #{v}", "\r\n"] end)

    client = mod.connect!(address, port, global)
    client |> Socket.packet!(:raw)
    client |> Socket.Stream.send!([
      "GET #{path} HTTP/1.1", "\r\n",
      headers,
      "Host: #{address}:#{port}", "\r\n",
      if(origin, do: ["Origin: #{origin}", "\r\n"], else: []),
      "Upgrade: websocket", "\r\n",
      "Connection: Upgrade", "\r\n",
      "Sec-WebSocket-Key: #{handshake}", "\r\n",
      if(protocols, do: ["Sec-WebSocket-Protocol: #{Enum.join protocols, ", "}", "\r\n"], else: []),
      if(extensions, do: ["Sec-WebSocket-Extensions: #{Enum.join extensions, ", "}", "\r\n"], else: []),
      "Sec-WebSocket-Version: 13", "\r\n",
      "\r\n"])

    client |> Socket.packet(:http_bin)
    { :http_response, _, 101, _ } = client |> Socket.Stream.recv!(global)
    headers                       = headers(%{}, client, local)

    if String.downcase(headers["upgrade"] || "") != "websocket" or
       String.downcase(headers["connection"] || "") != "upgrade" do
      client |> Socket.close

      raise RuntimeError, message: "malformed upgrade response"
    end

    if headers["sec-websocket-version"] && headers["sec-websocket-version"] != "13" do
      client |> Socket.close

      raise RuntimeError, message: "unsupported version"
    end

    if !headers["sec-websocket-accept"] or headers["sec-websocket-accept"] != key(handshake) do
      client |> Socket.close

      raise RuntimeError, message: "wrong key response"
    end

    client |> Socket.packet!(:raw)

    %W{socket: client, version: 13, path: path, origin: origin, key: handshake, mask: true}
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
  def listen(port) when port |> is_integer do
    listen(port, [])
  end

  def listen(options) do
    if options[:secure] do
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
    { local, global } = arguments(options)

    mod = if local[:secure] do
      Socket.SSL
    else
      Socket.TCP
    end

    case mod.listen(port, global) do
      { :ok, socket } ->
        { :ok, %W{socket: socket} }

      { :error, reason } ->
        { :error, reason }
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
  def listen!(port) when port |> is_integer do
    listen!(port, [])
  end

  def listen!(options) do
    if options[:secure] do
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
    { local, global } = arguments(options)

    mod = if local[:secure] do
      Socket.SSL
    else
      Socket.TCP
    end

    %W{socket: mod.listen!(port, global)}
  end

  @doc """
  If you're calling this on a listening socket, it accepts a new client
  connection.

  If you're calling this on a client socket, it finalizes the acception
  handshake, this separation is done because then you can verify the client can
  connect based on Origin header, path and other things.
  """
  @spec accept(t, Keyword.t) :: { :ok, t } | { :error, error }
  def accept(%W{key: nil} = self, options \\ []) do
    try do
      { :ok, accept!(self, options) }
    rescue
      MatchError ->
        { :error, "malformed handshake" }

      e in [RuntimeError] ->
        { :error, e.message }

      e in [Socket.Error] ->
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
  @spec accept!(t, Keyword.t) :: t | no_return
  def accept!(socket, options \\ [])

  def accept!(%W{socket: socket, key: nil}, options) do
    { local, global } = arguments(options)

    client = socket |> Socket.accept!(global)
    client |> Socket.packet!(:http_bin)

    path = case client |> Socket.Stream.recv!(global) do
      { :http_request, :GET, { :abs_path, path }, _ } ->
        path
    end

    headers = headers(%{}, client, local)

    if headers["upgrade"] != "websocket" and headers["connection"] != "Upgrade" do
      client |> Socket.close

      raise RuntimeError, message: "malformed upgrade request"
    end

    unless headers["sec-websocket-key"] do
      client |> Socket.close

      raise RuntimeError, message: "missing key"
    end

    protocols = if p = headers["sec-websocket-protocol"] do
      String.split(p, ~r/\s*,\s*/)
    end

    extensions = if e = headers["sec-websocket-extensions"] do
      String.split(e, ~r/\s*,\s*/)
    end

    client |> Socket.packet!(:raw)

    %W{socket: client,
       origin: headers["origin"],
       path: path,
       version: 13,
       key: headers["sec-websocket-key"],
       protocols: protocols,
       extensions: extensions,
       headers: headers}
  end

  def accept!(%W{socket: socket, key: key}, options) do
    { local, _ } = arguments(options)

    extensions = local[:extensions]
    protocol   = local[:protocol]

    socket |> Socket.packet!(:raw)
    socket |> Socket.Stream.send!([
      "HTTP/1.1 101 Switching Protocols", "\r\n",
      "Upgrade: websocket", "\r\n",
      "Connection: Upgrade", "\r\n",
      "Sec-WebSocket-Accept: #{key(key)}", "\r\n",
      "Sec-WebSocket-Version: 13", "\r\n",
      if(extensions, do: ["Sec-WebSocket-Extensions: ", Enum.join(extensions, ", "), "\r\n"], else: []),
      if(protocol, do: ["Sec-WebSocket-Protocol: ", protocol, "\r\n"], else: []),
      "\r\n" ])
    socket
  end

  @doc """
  Extract websocket specific options from the rest.
  """
  @spec arguments(Keyword.t) :: { Keyword.t, Keyword.t }
  def arguments(options) do
    options = Enum.group_by(options, fn
      { :secure, _ }     -> true
      { :path, _ }       -> true
      { :origin, _ }     -> true
      { :protocol, _ }   -> true
      { :extensions, _ } -> true
      { :handshake, _ }  -> true
      { :headers, _ }    -> true
      _                  -> false
    end)

    { Map.get(options, true, []), Map.get(options, false, []) }
  end

  @doc """
  Return the local address and port.
  """
  @spec local(t) :: { :ok, { :inet.ip_address, :inet.port_number } } | { :error, error }
  def local(%W{socket: socket}) do
    socket |> Socket.local
  end

  @doc """
  Return the local address and port, raising if an error occurs.
  """
  @spec local!(t) :: { :inet.ip_address, :inet.port_number } | no_return
  def local!(%W{socket: socket}) do
    socket |> Socket.local!
  end

  @doc """
  Return the remote address and port.
  """
  @spec remote(t) :: { :ok, { :inet.ip_address, :inet.port_number } } | { :error, error }
  def remote(%W{socket: socket}) do
    socket |> Socket.remote
  end

  @doc """
  Return the remote address and port, raising if an error occurs.
  """
  @spec remote!(t) :: { :inet.ip_address, :inet.port_number } | no_return
  def remote!(%W{socket: socket}) do
    socket |> Socket.remote!
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

  @spec recv(t, boolean, non_neg_integer, Keyword.t) :: { :ok, binary } | { :error, error }
  defp recv(%W{socket: socket, version: 13}, mask, length, options) do
    length = cond do
      length == 127 ->
        case socket |> Socket.Stream.recv(8, options) do
          { :ok, << length :: 64 >> } ->
            length

          { :error, reason } ->
            { :error, reason }
        end

      length == 126 ->
        case socket |> Socket.Stream.recv(2, options) do
          { :ok, << length :: 16 >> } ->
            length

          { :error, reason } ->
            { :error, reason }
        end

      length <= 125 ->
        length
    end

    case length do
      { :error, reason } ->
        { :error, reason }

      length ->
        if mask do
          case socket |> Socket.Stream.recv(4, options) do
            { :ok, << key :: 32 >> } ->
              if length > 0 do
                case socket |> Socket.Stream.recv(length, options) do
                  { :ok, data } ->
                    { :ok, unmask(key, data) }

                  { :error, reason } ->
                    { :error, reason }
                end
              else
                { :ok, "" }
              end

            { :error, reason } ->
              { :error, reason }
          end
        else
          if length > 0 do
            case socket |> Socket.Stream.recv(length, options) do
              { :ok, data } ->
                { :ok, data }

              { :error, reason } ->
                { :error, reason }
            end
          else
            { :ok, "" }
          end
        end
    end
  end

  defmacrop on_success(result, options) do
    quote do
      case recv(var!(self), var!(mask) == 1, var!(length), unquote(options)) do
        { :ok, var!(data) } ->
          { :ok, unquote(result) }

        { :error, reason } ->
          { :error, reason }
      end
    end
  end

  @doc """
  Receive a packet from the websocket.
  """
  @spec recv(t, Keyword.t) :: { :ok, packet } | { :error, error }
  def recv(self, options \\ [])
  def recv(%W{socket: socket, version: 13} = self, options) do
    case socket |> Socket.Stream.recv(2, options) do
      # a non fragmented message packet
      { :ok, << 1      :: 1,
                0      :: 3,
                opcode :: 4,
                mask   :: 1,
                length :: 7 >> } when known?(opcode) and data?(opcode) ->
        case on_success({ opcode(opcode), data }, options) do
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
        { :fragmented, opcode(opcode), data } |> on_success(options)

      # a fragmented continuation
      { :ok, << 0      :: 1,
                0      :: 3,
                0      :: 4,
                mask   :: 1,
                length :: 7 >> } ->
        { :fragmented, :continuation, data } |> on_success(options)

      # final fragmented packet
      { :ok, << 1      :: 1,
                0      :: 3,
                0      :: 4,
                mask   :: 1,
                length :: 7 >> } ->
        { :fragmented, :end, data } |> on_success(options)

      # control packet
      { :ok, << 1      :: 1,
                0      :: 3,
                opcode :: 4,
                mask   :: 1,
                length :: 7 >> } when known?(opcode) and control?(opcode) ->

        case opcode(opcode) do
          :ping -> { :ping, data }
          :pong -> { :pong, data }

          :close -> case data do
            <<>> -> :close

            << code :: 16, rest :: binary >> ->
              { :close, close_code(code), rest }
          end
        end |> on_success(options)

      { :ok, nil } ->
        # 1006 is reserved for connection closed with no close frame
        # https://tools.ietf.org/html/rfc6455#section-7.4.1
        { :ok, { :close, close_code(1006), nil } }

      { :ok, _ } ->
        { :error, :protocol_error }

      { :error, reason } ->
        { :error, reason }
    end
  end

  @doc """
  Receive a packet from the websocket, raising if an error occurs.
  """
  @spec recv!(t, Keyword.t) :: packet | no_return
  def recv!(self, options \\ []) do
    case recv(self, options) do
      { :ok, packet } ->
        packet

      { :error, :protocol_error } ->
        raise RuntimeError, message: "protocol error"

      { :error, code } ->
        raise Socket.Error, reason: code
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
  @spec send(t, packet)            :: :ok | { :error, error }
  @spec send(t, packet, Keyword.t) :: :ok | { :error, error }
  def send(self, packet, options \\ [])

  def send(%W{socket: socket, version: 13, mask: mask}, { opcode, data }, options) when opcode != :close do
    mask = if Keyword.has_key?(options, :mask), do: options[:mask], else: mask

    socket |> Socket.Stream.send(
      << 1              :: 1,
         0              :: 3,
         opcode(opcode) :: 4,
         forge(mask, data) :: binary >>)
  end

  def send(%W{socket: socket, version: 13, mask: mask}, { :fragmented, :end, data }, options) do
    mask = if Keyword.has_key?(options, :mask), do: options[:mask], else: mask

    socket |> Socket.Stream.send(
      << 1 :: 1,
         0 :: 3,
         0 :: 4,
         forge(mask, data) :: binary >>)
  end

  def send(%W{socket: socket, version: 13, mask: mask}, { :fragmented, :continuation, data }, options) do
    mask = if Keyword.has_key?(options, :mask), do: options[:mask], else: mask

    socket |> Socket.Stream.send(
      << 0 :: 1,
         0 :: 3,
         0 :: 4,
         forge(mask, data) :: binary >>)
  end

  def send(%W{socket: socket, version: 13, mask: mask}, { :fragmented, opcode, data }, options) do
    mask = if Keyword.has_key?(options, :mask), do: options[:mask], else: mask

    socket |> Socket.Stream.send(
      << 0              :: 1,
         0              :: 3,
         opcode(opcode) :: 4,
         forge(mask, data) :: binary >>)
  end

  @doc """
  Send a packet to the websocket, raising if an error occurs.
  """
  @spec send!(t, packet)            :: :ok | no_return
  @spec send!(t, packet, Keyword.t) :: :ok | no_return
  def send!(self, packet, options \\ []) do
    case send(self, packet, options) do
      :ok ->
        :ok

      { :error, code } ->
        raise Socket.Error, reason: code
    end
  end

  @doc """
  Send a ping request with the optional cookie.
  """
  @spec ping(t)         :: :ok | { :error, error }
  @spec ping(t, binary) :: :ok | { :error, error }
  def ping(self, cookie \\ :crypto.strong_rand_bytes(32)) do
    case send(self, { :ping, cookie }) do
      :ok ->
        cookie

      { :error, reason } ->
        { :error, reason }
    end
  end

  @doc """
  Send a ping request with the optional cookie, raising if an error occurs.
  """
  @spec ping!(t)         :: :ok | no_return
  @spec ping!(t, binary) :: :ok | no_return
  def ping!(self, cookie \\ :crypto.strong_rand_bytes(32)) do
    send!(self, { :ping, cookie })

    cookie
  end

  @doc """
  Send a pong with the given (and received) ping cookie.
  """
  @spec pong(t, binary) :: :ok | { :error, error }
  def pong(self, cookie) do
    send(self, { :pong, cookie })
  end

  @doc """
  Send a pong with the given (and received) ping cookie, raising if an error
  occurs.
  """
  @spec pong!(t, binary) :: :ok | no_return
  def pong!(self, cookie) do
    send!(self, { :pong, cookie })
  end

  @doc """
  Close the socket when a close request has been received.
  """
  @spec close(t) :: :ok | { :error, error }
  def close(%W{socket: socket, version: 13}) do
    socket |> Socket.Stream.send(
      << 1              :: 1,
         0              :: 3,
         opcode(:close) :: 4,

         forge(nil, <<>>) :: binary >>)
  end

  @doc """
  Close the socket sending a close request, unless `:wait` is set to `false` it
  blocks until the close response has been received, and then closes the
  underlying socket.
  If :reason? is set to true and the response contains a closing reason
  and custom data the function returns it as a tuple.
  """
  @spec close(t, atom, Keyword.t) :: :ok  | {:ok, atom, binary} | { :error, error }
  def close(%W{socket: socket, version: 13, mask: mask} = self, reason, options \\ []) do
    { reason, data } = if is_tuple(reason), do: reason, else: { reason, <<>> }
    mask             = if Keyword.has_key?(options, :mask), do: options[:mask], else: mask

    socket |> Socket.Stream.send(
      << 1              :: 1,
         0              :: 3,
         opcode(:close) :: 4,

         forge(mask,
           << close_code(reason) :: 16, data :: binary >>) :: binary >>)

    unless options[:wait] == false do
      do_close(self, recv(self, options), Keyword.get(options, :reason?, false), options)
    end
  end

  defp do_close(self, { :ok, :close }, _, _) do
    abort(self)
  end

  defp do_close(self, { :ok, { :close, _, _ } }, false, _) do
    abort(self)
  end

  defp do_close(self, { :ok, { :close, reason, data } }, true, _) do
    abort(self)
    {:ok, reason, data}
  end

  defp do_close(self, { :ok, { :error, _ } }, _, _) do
    abort(self)
  end

  defp do_close(self, _, reason?, options) do
    do_close(self, recv(self, options), reason?, options)
  end

  @doc """
  Close the underlying socket, only use when you mean it, normal closure
  procedure should be preferred.
  """
  @spec abort(t) :: :ok | { :error, error }
  def abort(%W{socket: socket}) do
    Socket.Stream.close(socket)
  end
end
