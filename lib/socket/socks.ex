#            DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE
#                    Version 2, December 2004
#
#            DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE
#   TERMS AND CONDITIONS FOR COPYING, DISTRIBUTION AND MODIFICATION
#
#  0. You just DO WHAT THE FUCK YOU WANT TO.

defmodule Socket.SOCKS do
  use Socket.Helpers

  def connect(to, through, options \\ []) do
    [address, port | auth] = through |> Tuple.to_list

    with { :ok, socket } <- pre(address, port, options),
         :ok             <- handshake(socket, options[:version] || 5, auth |> List.to_tuple, to),
         :ok             <- post(socket, options)
    do
      { :ok, socket }
    else
      { :error, reason } ->
        { :error, reason }
    end
  end

  defbang connect(to, through)
  defbang connect(to, through, options)

  defp pre(address, port, options) do
    options = if options[:mode] == :active || options[:mode] == :once do
      options
        |> Keyword.put(:mode, :passive)
    else
      options
    end

    Socket.TCP.connect(address, port, options)
  end

  defp handshake(socket, 4, auth, { address, port }) do
    user = if tuple_size(auth) >= 1 do
      auth |> elem(0)
    else
      ""
    end

    case Socket.Address.parse(address) do
      { a, b, c, d } ->
        case socket |> Socket.Stream.send(<<
          # version
          0x04 :: 8,

          # make a stream TCP connection
          0x01 :: 8,

          # port in network byte order
          port :: big-size(16),

          # IP address in network byte order
          a :: 8,
          b :: 8,
          c :: 8,
          d :: 8,

          # user name followed by NULL
          user :: binary,
          0x00 :: 8 >>)
        do
          :ok ->
            response(socket, 4)

          { :error, reason } ->
            { :error, reason }
        end

      nil ->
        case socket |> Socket.Stream.send(<<
          # version
          0x04 :: 8,

          # make a stream TCP connection
          0x01 :: 8,

          # port in network byte order
          port :: big-size(16),

          # invalid IP address
          0x00 :: 8,
          0x00 :: 8,
          0x00 :: 8,
          0xff :: 8,

          # user name followed by NULL
          user :: binary,
          0x00 :: 8,

          # host followed by NULL
          address :: binary,
          0x00    :: 8 >>)
        do
          :ok ->
            response(socket, 4)

          { :error, reason } ->
            { :error, reason}
        end
    end
  end

  defp handshake(_socket, 5, _auth, { _address, _port }) do
    { :error, :hue }
  end

  defp response(socket, 4) do
    case socket |> Socket.Stream.recv(8) do
      # request granted
      { :ok, << 0x00 :: 8, 0x5a :: 8, _ :: 16, _ :: 32 >> } ->
        :ok

      # request rejected or failed
      { :ok, << 0x00 :: 8, 0x5b :: 8, _ :: 16, _ :: 32 >> } ->
        { :error, :rejected }

      # request failed because client is not running identd (or not
      # reachable from the server)
      { :ok, << 0x00 :: 8, 0x5c :: 8, _ :: 16, _ :: 32 >> } ->
        { :error, :unreachable }

      # request failed because client's identd could not confirm the
      # user ID string in the request
      { :ok, << 0x00 :: 8, 0x5d :: 8, _ :: 16, _ :: 32 >> } ->
        { :error, :unauthorized }

      { :error, reason } ->
        { :error, reason }
    end
  end

  defp response(_socket, 5) do
    { :error, :hue }
  end

  defp post(socket, options) do
    cond do
      options[:mode] == :active ->
        socket |> Socket.active

      options[:mode] == :once ->
        socket |> Socket.active(:once)

      true ->
        :ok
    end
  end
end
