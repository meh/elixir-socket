#            DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE
#                    Version 2, December 2004
#
#            DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE
#   TERMS AND CONDITIONS FOR COPYING, DISTRIBUTION AND MODIFICATION
#
#  0. You just DO WHAT THE FUCK YOU WANT TO.

defmodule Socket.SSL do
  @doc """
  Get the list of supported ciphers.
  """
  @spec ciphers :: [:ssl.erl_cipher_suite]
  def ciphers do
    :ssl.cipher_suites
  end

  @doc """
  Get the list of supported SSL/TLS versions.
  """
  @spec versions :: [tuple]
  def versions do
    :ssl.versions
  end

  defexception Error, code: nil do
    def message(self) do
      to_binary(:ssl.format_error(self.code))
    end
  end

  @type t :: record

  defrecordp :socket, ssl: nil, reference: nil

  @doc """
  Wrap an existing socket.
  """
  @spec wrap(port) :: t
  def wrap(sock) do
    socket(ssl: sock)
  end

  @doc """
  Connect to the given address and port tuple or SSL connect the given socket.
  """
  @spec connect(Socket.t | { Socket.t, :inet.port_number }) :: { :ok, t } | { :error, term }
  def connect({ address, port }) do
    connect(address, port)
  end

  def connect(socket) do
    connect(socket, [])
  end

  @doc """
  Connect to the given address and port tuple with the given options or SSL
  connect the given socket with the given options or connect to the given
  address and port.
  """
  @spec connect({ Socket.Address.t, :inet.port_number } | Socket.t | Socket.Address.t, Keyword.t | :inet.port_number) :: { :ok, t } | { :error, term }
  def connect({ address, port }, options) when is_list(options) do
    connect(address, port, options)
  end

  def connect(wrap, options) when is_list(options) do
    unless is_port(wrap) do
      wrap = wrap.to_port
    end

    case :ssl.connect(wrap, options, options[:timeout] || :infinity) do
      { :ok, sock } ->
        { :ok, socket(ssl: sock, reference: wrap) }

      error ->
        error
    end
  end

  def connect(address, port) when is_integer(port) do
    connect(address, port, [])
  end

  @doc """
  Connect to the given address and port with the given options.
  """
  @spec connect(Socket.Address.t, :inet.port_number, Keyword.t) :: { :ok, t } | { :error, term }
  def connect(address, port, options) do
    if is_binary(address) do
      address = binary_to_list(address)
    end

    options = Keyword.put_new(options, :mode, :passive)

    case :ssl.connect(address, port, arguments(options), options[:timeout] || :infinity) do
      { :ok, sock } ->
        reference = if (options[:mode] == :passive and options[:automatic] != false) or
                       (options[:mode] == :active  and options[:automatic] == true) do
          :ssl.controlling_process(sock, Process.whereis(Socket.Manager))
          Finalizer.define({ :close, :ssl, sock }, Process.whereis(Socket.Manager))
        end

        { :ok, socket(ssl: sock, reference: reference) }

      error ->
        error
    end
  end

  @doc """
  Connect to the given address and port tuple or SSL connect the given socket,
  raising if an error occurs.
  """
  @spec connect!(Socket.t | { Socket.t, :inet.port_number }) :: t | no_return
  def connect!({ address, port }) do
    connect!(address, port)
  end

  def connect!(socket) do
    connect!(socket, [])
  end

  @doc """
  Connect to the given address and port tuple with the given options or SSL
  connect the given socket with the given options or connect to the given
  address and port, raising if an error occurs.
  """
  @spec connect!({ Socket.Address.t, :inet.port_number } | Socket.t | Socket.Address.t, Keyword.t | :inet.port_number) :: t | no_return
  def connect!({ address, port }, options) when is_list(options) do
    connect!(address, port, options)
  end

  def connect!(socket, options) when is_list(options) do
    case connect(socket, options) do
      { :ok, socket } ->
        socket

      { :error, code } ->
        raise Error, code: code
    end
  end

  def connect!(address, port) when is_integer(port) do
    connect!(address, port, [])
  end

  @doc """
  Connect to the given address and port with the given options, raising if an
  error occurs.
  """
  @spec connect!(Socket.Address.t, :inet.port_number, Keyword.t) :: t | no_return
  def connect!(address, port, options) do
    case connect(address, port, options) do
      { :ok, socket } ->
        socket

      { :error, code } ->
        raise Error, code: code
    end
  end

  @doc """
  Create an SSL socket listening on an OS chosen port, use `local` to know the
  port it was bound on.
  """
  @spec listen :: { :ok, t } | { :error, term }
  def listen do
    listen(0, [])
  end

  @doc """
  Create an SSL socket listening on an OS chosen port using the given options or
  listening on the given port.
  """
  @spec listen(:inet.port_number | Keyword.t) :: { :ok, t } | { :error, term }
  def listen(port) when is_integer(port) do
    listen(port, [])
  end

  def listen(options) do
    listen(0, options)
  end

  @doc """
  Create an SSL socket listening on the given port and using the given options.
  """
  @spec listen(:inet.port_number, Keyword.t) :: { :ok, t } | { :error, term }
  def listen(port, options) do
    options = Keyword.put(options, :mode, :passive)
    options = Keyword.put_new(options, :reuseaddr, true)

    case :ssl.listen(port, arguments(options)) do
      { :ok, sock } ->
        reference = if options[:automatic] != false do
          :ssl.controlling_process(sock, Process.whereis(Socket.Manager))
          Finalizer.define({ :close, :ssl, sock }, Process.whereis(Socket.Manager))
        end

        { :ok, socket(ssl: sock, reference: reference) }

      error ->
        error
    end
  end

  @doc """
  Create an SSL socket listening on an OS chosen port, use `local` to know the
  port it was bound on, raising in case of error.
  """
  @spec listen! :: t | no_return
  def listen! do
    listen!(0, [])
  end

  @doc """
  Create an SSL socket listening on an OS chosen port using the given options
  or listening on the given port, raising in case of error.
  """
  @spec listen!(:inet.port_number | Keyword.t) :: t | no_return
  def listen!(port) when is_integer(port) do
    listen!(port, [])
  end

  def listen!(options) do
    listen!(0, options)
  end

  @doc """
  Create an SSL socket listening on the given port and using the given options,
  raising in case of error.
  """
  @spec listen!(:inet.port_number, Keyword.t) :: t | no_return
  def listen!(port, options) do
    case listen(port, options) do
      { :ok, socket } ->
        socket

      { :error, code } ->
        raise Error, code: code
    end
  end

  @doc """
  Accept a connection from a listening SSL socket or start an SSL connection on
  the given client socket.
  """
  @spec accept(Socket.t | t) :: { :ok, t } | { :error, term }
  def accept(socket() = self) do
    accept([], self)
  end

  def accept(wrap) do
    accept(wrap, [])
  end

  @doc """
  Accept a connection from a listening SSL socket with the given options or
  start an SSL connection on the given client socket with the given options.
  """
  @spec accept(Keyword.t | Socket.t, t | Keyword.t) :: { :ok, t } | { :error, term }
  def accept(options, socket(ssl: sock)) do
    options = Keyword.put_new(options, :mode, :passive)

    case :ssl.transport_accept(sock, options[:timeout] || :infinity) do
      { :ok, sock } ->
        reference = if (options[:mode] == :passive and options[:automatic] != false) or
                       (options[:mode] == :active  and options[:automatic] == true) do
          :ssl.controlling_process(sock, Process.whereis(Socket.Manager))
          Finalizer.define({ :close, :ssl, sock }, Process.whereis(Socket.Manager))
        end

        result = if options[:mode] == :active do
          :ssl.setopts(sock, [{ :active, true }])
        else
          :ok
        end

        if result == :ok do
          sock   = socket(ssl: sock, reference: reference)
          result = sock.handshake(timeout: options[:timeout] || :infinity)

          if result == :ok do
            { :ok, sock }
          else
            result
          end
        else
          result
        end

      error ->
        error
    end
  end

  def accept(wrap, options) do
    unless is_port(wrap) do
      wrap = wrap.to_port
    end

    case :ssl.ssl_accept(wrap, arguments(options), options[:timeout] || :infinity) do
      { :ok, sock } ->
        { :ok, socket(ssl: sock, reference: wrap) }

      error ->
        error
    end
  end

  @doc """
  Accept a connection from a listening SSL socket or start an SSL connection on
  the given client socket, raising if an error occurs.
  """
  @spec accept!(Socket.t | t) :: t | no_return
  def accept!(socket() = self) do
    accept!([], self)
  end

  def accept!(socket) do
    accept!(socket, [])
  end

  @doc """
  Accept a connection from a listening SSL socket with the given options or
  start an SSL connection on the given client socket with the given options,
  raising if an error occurs.
  """
  @spec accept!(Keyword.t | Socket.t, t | Keyword.t) :: t | no_return
  def accept!(options, socket() = self) do
    case accept(options, self) do
      { :ok, socket } ->
        socket

      { :error, code } ->
        raise Error, code: code
    end
  end

  def accept!(socket, options) do
    case accept(self, options) do
      { :ok, socket } ->
        socket

      { :error, code } ->
        raise Error, code: code
    end
  end

  @doc """
  Execute the handshake; useful if you want to delay the handshake to make it
  in another process.
  """
  @spec handshake(t)            :: :ok | { :error, term }
  @spec handshake(Keyword.t, t) :: :ok | { :error, term }
  def handshake(options // [], socket(ssl: sock)) do
    :ssl.ssl_accept(sock, options[:timeout] || :infinity)
  end

  @doc """
  Execute the handshake, raising if an error occurs; useful if you want to
  delay the handshake to make it in another process.
  """
  @spec handshake!(t)            :: :ok | no_return
  @spec handshake!(Keyword.t, t) :: :ok | no_return
  def handshake!(options // [], socket() = self) do
    case handshake(options, self) do
      :ok ->
        :ok

      { :error, code } ->
        raise Error, code: code
    end
  end

  @doc """
  Set options of the socket.
  """
  @spec options(Keyword.t, t) :: :ok | { :error, :inet.posix }
  def options(opts, socket(ssl: sock)) do
    :ssl.setopts(sock, arguments(opts))
  end

  @doc """
  Set options of the socket, raising if an error occurs.
  """
  @spec options!(Keyword.t, t) :: :ok | no_return
  def options!(opts, self) do
    case options(opts, self) do
      :ok ->
        :ok

      { :error, code } ->
        raise Socket.Error, code: code
    end
  end

  @doc """
  Get information about the SSL connection.
  """
  @spec info(t) :: { :ok, list } | { :error, term }
  def info(socket(ssl: sock)) do
    :ssl.connection_info(sock)
  end

  @doc """
  Get information about the SSL connection, raising if an error occurs.
  """
  @spec info!(t) :: list | no_return
  def info!(self) do
    case info(self) do
      { :ok, info } ->
        info

      { :error, code } ->
        raise Error, code: code
    end
  end

  @doc """
  Get the certificate of the peer.
  """
  @spec certificate(t) :: { :ok, String.t } | { :error, term }
  def certificate(socket(ssl: sock)) do
    :ssl.peercert(sock)
  end

  @doc """
  Get the certificate of the peer, raising if an error occurs.
  """
  @spec certificate!(t) :: String.t | no_return
  def certificate!(self) do
    case certificate(self) do
      { :ok, cert } ->
        cert

      { :error, code } ->
        raise Error, code: code
    end
  end

  @doc """
  Return the local address and port.
  """
  @spec local(t) :: { :ok, { :inet.ip_address, :inet.port_number } } | { :error, term }
  def local(socket(ssl: sock)) do
    :ssl.sockname(sock)
  end

  @doc """
  Return the local address and port, raising if an error occurs.
  """
  @spec local!(t) :: { :inet.ip_address, :inet.port_number } | no_return
  def local!(socket(ssl: sock)) do
    case :ssl.sockname(sock) do
      { :ok, result } ->
        result

      { :error, code } ->
        raise Error, code: code
    end
  end

  @doc """
  Return the remote address and port.
  """
  @spec remote(t) :: { :ok, { :inet.ip_address, :inet.port_number } } | { :error, term }
  def remote(socket(ssl: sock)) do
    :ssl.peername(sock)
  end

  @doc """
  Return the remote address and port, raising if an error occurs.
  """
  @spec remote!(t) :: { :inet.ip_address, :inet.port_number } | no_return
  def remote!(socket(ssl: sock)) do
    case :ssl.peername(sock) do
      { :ok, result } ->
        result

      { :error, code } ->
        raise Error, code: code
    end
  end

  @doc """
  Send a packet through the socket.
  """
  @spec send(iodata, t) :: :ok | { :error, term }
  def send(value, socket(ssl: sock)) do
    :ssl.send(sock, value)
  end

  @doc """
  Send a packet through the socket, raising if an error occurs.
  """
  @spec send!(iodata, t) :: :ok | no_return
  def send!(value, self) do
    case send(value, self) do
      :ok ->
        :ok

      { :error, code } ->
        raise Error, code: code
    end
  end

  @doc """
  Receive a packet from the socket, following the `:packet` option set at
  creation.
  """
  @spec recv(t) :: { :ok, binary | char_list } | { :error, :inet.posix }
  def recv(socket(ssl: sock)) do
    :ssl.recv(sock, 0)
  end

  @doc """
  Receive a packet from the socket, with either the given length or the given
  options.
  """
  @spec recv(non_neg_integer | Keyword.t, t) :: { :ok, binary | char_list } | { :error, :inet.posix }
  def recv(length, socket(ssl: sock)) when is_integer(length) do
    :ssl.recv(sock, length)
  end

  def recv(options, self) do
    recv(0, options, self)
  end

  @doc """
  Receive a packet from the socket with the given length and options.
  """
  @spec recv(non_neg_integer, Keyword.t, t) :: { :ok, binary | char_list } | { :error, :inet.posix }
  def recv(length, options, socket(ssl: sock)) do
    if timeout = options[:timeout] do
      :ssl.recv(sock, length, timeout)
    else
      :ssl.recv(sock, length)
    end
  end

  @doc """
  Receive a packet from the socket, following the `:packet` option set at
  creation, raising if an error occurs.
  """
  @spec recv!(t) :: binary | char_list | no_return
  def recv!(self) do
    case recv(self) do
      { :ok, packet } ->
        packet

      { :error, code } ->
        raise Error, code: code
    end
  end

  @doc """
  Receive a packet from the socket, with either the given length or the given
  options, raising if an error occurs.
  """
  @spec recv!(non_neg_integer | Keyword.t, t) :: binary | char_list | no_return
  def recv!(length_or_options, self) do
    case recv(length_or_options, self) do
      { :ok, packet } ->
        packet

      { :error, code } ->
        raise Error, code: code
    end
  end

  @doc """
  Receive a packet from the socket with the given length and options, raising
  if an error occurs.
  """
  @spec recv!(non_neg_integer, Keyword.t, t) :: binary | char_list | no_return
  def recv!(length, options, self) do
    case recv(length, options, self) do
      { :ok, packet } ->
        packet

      { :error, code } ->
        raise Error, code: code
    end
  end

  @doc """
  Renegotiate the secure connection.
  """
  @spec renegotiate(t) :: :ok | { :error, term }
  def renegotiate(socket(ssl: sock)) do
    :ssl.renegotiate(sock)
  end

  @doc """
  Renegotiate the secure connection, raising if an error occurs.
  """
  @spec renegotiate!(t) :: :ok | no_return
  def renegotiate!(self) do
    case renegotiate(self) do
      :ok ->
        :ok

      { :error, code } ->
        raise Error, code: code
    end
  end

  @doc """
  Shutdown the socket for the given mode.
  """
  @spec shutdown(:read | :write | :both, t) :: :ok | { :error, term }
  def shutdown(how, socket(ssl: sock)) do
    :ssl.shutdown(sock, case how do
      :read  -> :read
      :write -> :write
      :both  -> :read_write
    end)
  end

  @doc """
  Shutdown the socket for the given mode, raising if an error occurs.
  """
  @spec shutdown!(:read | :write | :both, t) :: :ok | no_return
  def shutdown!(how, self) do
    case shutdown(how, self) do
      :ok ->
        :ok

      { :error, code } ->
        raise Error, code: code
    end
  end

  @doc """
  Close the socket, if smart garbage collection is used, the socket will be
  closed automatically when it's not referenced by anything.
  """
  @spec close(t) :: :ok | { :error, term }
  def close(socket(ssl: sock)) do
    :ssl.close(sock)
  end

  @doc """
  Close the socket, raising if an error occurs, if smart garbage collection is
  used, the socket will be closed automatically when it's not referenced by
  anything.
  """
  @spec close!(t) :: :ok | no_return
  def close!(self) do
    case close(self) do
      :ok ->
        :ok

      { :error, code } ->
        raise Error, code: code
    end
  end

  @doc """
  Convert SSL options to `:ssl.setopts` compatible arguments.
  """
  @spec arguments(Keyword.t) :: list
  def arguments(options) do
    args = Socket.TCP.arguments(options)

    args = case options[:cert] do
      [path: path] ->
        [{ :certfile, path } | args]

      nil ->
        args

      content ->
        [{ :cert, content } | args]
    end

    args = case options[:key] do
      [path: path] ->
        [{ :keyfile, path } | args]

      [rsa: content] ->
        [{ :key, { :RSAPrivateKey, content } } | args]

      [dsa: content] ->
        [{ :key, { :DSAPrivateKey, content } } | args]

      nil ->
        args

      content ->
        [{ :key, { :PrivateKeyInfo, content } } | args]
    end

    args = case options[:authorities] do
      [path: path] ->
        [{ :cacertfile, path } | args]

      nil ->
        args

      content ->
        [{ :cacert, content } | args]
    end

    args = case options[:dh] do
      [path: path] ->
        [{ :dhfile, path } | args]

      nil ->
        args

      content ->
        [{ :dh, content } | args]
    end

    args = case options[:verify] do
      false ->
        [{ :verify, :verify_none } | args]

      [function: fun] ->
        [{ :verify_fun, { fun, nil } } | args]

      [function: fun, data: data] ->
        [{ :verify_fun, { fun, data } } | args]

      nil ->
        args
    end

    if options[:password] do
      args = [{ :password, options[:password] } | args]
    end

    if options[:renegotiation] == :secure do
      args = [{ :secure_renegotiate, true } | args]
    end

    if options[:ciphers] do
      args = [{ :ciphers, options[:ciphers] } | args]
    end

    if options[:depth] do
      args = [{ :depth, options[:depth] } | args]
    end

    if options[:versions] do
      args = [{ :versions, options[:versions] } | args]
    end

    if options[:hibernate] do
      args = [{ :hibernate_after, options[:hibernate] } | args]
    end

    if is_function(options[:reuse]) do
      args = [{ :reuse_session, options[:reuse] } | args]
    end

    if options[:reuse] == true do
      args = [{ :reuse_sessions, true } | args]
    end

    args
  end
end
