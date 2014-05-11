#            DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE
#                    Version 2, December 2004
#
#            DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE
#   TERMS AND CONDITIONS FOR COPYING, DISTRIBUTION AND MODIFICATION
#
#  0. You just DO WHAT THE FUCK YOU WANT TO.

defmodule Socket.SSL do
  @moduledoc """
  This module allows usage of SSL sockets and promotion of TCP sockets to SSL
  sockets.

  ## Options

  When creating a socket you can pass a serie of options to use for it.

  * `:cert` can either be an encoded certificate or `[path:
    "path/to/certificate"]`
  * `:key` can either be an encoded certificate, `[path: "path/to/key]`, `[rsa:
    "rsa encoded"]` or `[dsa: "dsa encoded"]`
  * `:authorities` can iehter be an encoded authorities or `[path:
    "path/to/authorities"]`
  * `:dh` can either be an encoded dh or `[path: "path/to/dh"]`
  * `:verify` can either be `false` to disable peer certificate verification,
    or a keyword list containing a `:function` and an optional `:data`
  * `:password` the password to use to decrypt certificates
  * `:renegotiation` if it's set to `:secure` renegotiation will be secured
  * `:ciphers` is a list of ciphers to allow
  * `:advertised_protocols` is a list of strings representing the advertised
    protocols for NPN

  You can also pass TCP options.

  ## Smart garbage collection

  Normally sockets in Erlang are closed when the controlling process exits,
  with smart garbage collection the controlling process will be the
  `Socket.Manager` and it will be closed when there are no more references to
  it.
  """

  use Socket.Helpers
  require Record

  @opaque t :: port

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

  @doc """
  Return a proper error string for the given code or nil if it can't be
  converted.
  """
  @spec error(term) :: String.t
  def error(code) do
    case :ssl.format_error(code) do
      'Unexpected error:' ++ _ ->
        nil

      message ->
        message |> to_string
    end
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
  Connect to the given address and port tuple or SSL connect the given socket,
  raising if an error occurs.
  """
  @spec connect!(Socket.t | { Socket.t, :inet.port_number }) :: t | no_return
  defbang connect(socket_or_descriptor)

  @doc """
  Connect to the given address and port tuple with the given options or SSL
  connect the given socket with the given options or connect to the given
  address and port.
  """
  @spec connect({ Socket.Address.t, :inet.port_number } | Socket.t | Socket.Address.t, Keyword.t | :inet.port_number) :: { :ok, t } | { :error, term }
  def connect({ address, port }, options) when options |> is_list do
    connect(address, port, options)
  end

  def connect(wrap, options) when options |> is_list do
    unless wrap |> is_port do
      wrap = wrap.to_port
    end

    :ssl.connect(wrap, options, options[:timeout] || :infinity)
  end

  def connect(address, port) when port |> is_integer do
    connect(address, port, [])
  end

  @doc """
  Connect to the given address and port tuple with the given options or SSL
  connect the given socket with the given options or connect to the given
  address and port, raising if an error occurs.
  """
  @spec connect!({ Socket.Address.t, :inet.port_number } | Socket.t | Socket.Address.t, Keyword.t | :inet.port_number) :: t | no_return
  defbang connect(descriptor, options)

  @doc """
  Connect to the given address and port with the given options.
  """
  @spec connect(Socket.Address.t, :inet.port_number, Keyword.t) :: { :ok, t } | { :error, term }
  def connect(address, port, options) do
    if address |> is_binary do
      address = String.to_char_list!(address)
    end

    options = Keyword.put_new(options, :mode, :passive)

    :ssl.connect(address, port, arguments(options), options[:timeout] || :infinity)
  end

  @doc """
  Connect to the given address and port with the given options, raising if an
  error occurs.
  """
  @spec connect!(Socket.Address.t, :inet.port_number, Keyword.t) :: t | no_return
  defbang connect(address, port, options)

  @doc """
  Create an SSL socket listening on an OS chosen port, use `local` to know the
  port it was bound on.
  """
  @spec listen :: { :ok, t } | { :error, term }
  def listen do
    listen(0, [])
  end

  @doc """
  Create an SSL socket listening on an OS chosen port, use `local` to know the
  port it was bound on, raising in case of error.
  """
  @spec listen! :: t | no_return
  defbang listen

  @doc """
  Create an SSL socket listening on an OS chosen port using the given options or
  listening on the given port.
  """
  @spec listen(:inet.port_number | Keyword.t) :: { :ok, t } | { :error, term }
  def listen(port) when port |> is_integer do
    listen(port, [])
  end

  def listen(options) do
    listen(0, options)
  end

  @doc """
  Create an SSL socket listening on an OS chosen port using the given options
  or listening on the given port, raising in case of error.
  """
  @spec listen!(:inet.port_number | Keyword.t) :: t | no_return
  defbang listen(port_or_options)

  @doc """
  Create an SSL socket listening on the given port and using the given options.
  """
  @spec listen(:inet.port_number, Keyword.t) :: { :ok, t } | { :error, term }
  def listen(port, options) do
    options = Keyword.put(options, :mode, :passive)
    options = Keyword.put_new(options, :reuseaddr, true)

    :ssl.listen(port, arguments(options))
  end

  @doc """
  Create an SSL socket listening on the given port and using the given options,
  raising in case of error.
  """
  @spec listen!(:inet.port_number, Keyword.t) :: t | no_return
  defbang listen(port, options)

  @doc """
  Accept a connection from a listening SSL socket or start an SSL connection on
  the given client socket.
  """
  @spec accept(Socket.t | t) :: { :ok, t } | { :error, term }
  def accept(self) do
    accept(self, [])
  end

  @doc """
  Accept a connection from a listening SSL socket or start an SSL connection on
  the given client socket, raising if an error occurs.
  """
  @spec accept!(Socket.t | t) :: t | no_return
  defbang accept(socket)

  @doc """
  Accept a connection from a listening SSL socket with the given options or
  start an SSL connection on the given client socket with the given options.
  """
  @spec accept(Socket.t, Keyword.t) :: { :ok, t } | { :error, term }
  def accept(sock, options) when sock |> Record.record?(:sslsocket) do
    options = Keyword.put_new(options, :mode, :passive)

    case :ssl.transport_accept(sock, options[:timeout] || :infinity) do
      { :ok, sock } ->
        result = if options[:mode] == :active do
          :ssl.setopts(sock, [{ :active, true }])
        else
          :ok
        end

        if result == :ok do
          result = sock |> handshake(timeout: options[:timeout] || :infinity)

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

  def accept(wrap, options) when wrap |> is_port do
    :ssl.ssl_accept(wrap, arguments(options), options[:timeout] || :infinity)
  end

  @doc """
  Accept a connection from a listening SSL socket with the given options or
  start an SSL connection on the given client socket with the given options,
  raising if an error occurs.
  """
  @spec accept!(Socket.t, t | Keyword.t) :: t | no_return
  defbang accept(socket, options)

  @doc """
  Execute the handshake; useful if you want to delay the handshake to make it
  in another process.
  """
  @spec handshake(t)            :: :ok | { :error, term }
  @spec handshake(t, Keyword.t) :: :ok | { :error, term }
  def handshake(sock, options \\ []) when sock |> Record.record?(:sslsocket) do
    :ssl.ssl_accept(sock, options[:timeout] || :infinity)
  end

  @doc """
  Execute the handshake, raising if an error occurs; useful if you want to
  delay the handshake to make it in another process.
  """
  @spec handshake!(t)            :: :ok | no_return
  @spec handshake!(t, Keyword.t) :: :ok | no_return
  defbang handshake(sock)
  defbang handshake(sock, options)

  @doc """
  Set the process which will receive the messages.
  """
  @spec process(t | port, pid) :: :ok | { :error, :closed | :not_owner | Error.t }
  def process(sock, pid) when sock |> Record.record?(:sslsocket) do
    :ssl.controlling_process(sock, pid)
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
  @spec options(t | :ssl.sslsocket, Keyword.t) :: :ok | { :error, Socket.Error.t }
  def options(socket, options) when socket |> Record.record?(:sslsocket) do
    :ssl.setopts(socket, arguments(options))
  end

  @doc """
  Set options of the socket, raising if an error occurs.
  """
  @spec options!(t | Socket.SSL.t | port, Keyword.t) :: :ok | no_return
  defbang options(socket, options)

  @doc """
  Convert SSL options to `:ssl.setopts` compatible arguments.
  """
  @spec arguments(Keyword.t) :: list
  def arguments(options) do
    args = Socket.TCP.arguments(options)

    args = case Keyword.get(options, :cert) do
      [path: path] ->
        [{ :certfile, path } | args]

      nil ->
        args

      content ->
        [{ :cert, content } | args]
    end

    args = case Keyword.get(options, :key) do
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

    args = case Keyword.get(options, :authorities) do
      [path: path] ->
        [{ :cacertfile, path } | args]

      nil ->
        args

      content ->
        [{ :cacert, content } | args]
    end

    args = case Keyword.get(options, :dh) do
      [path: path] ->
        [{ :dhfile, path } | args]

      nil ->
        args

      content ->
        [{ :dh, content } | args]
    end

    args = case Keyword.get(options, :verify) do
      false ->
        [{ :verify, :verify_none } | args]

      [function: fun] ->
        [{ :verify_fun, { fun, nil } } | args]

      [function: fun, data: data] ->
        [{ :verify_fun, { fun, data } } | args]

      nil ->
        args
    end

    if password = Keyword.get(options, :password) do
      args = [{ :password, password } | args]
    end

    if Keyword.get(options, :renegotiation) == :secure do
      args = [{ :secure_renegotiate, true } | args]
    end

    if ciphers = Keyword.get(options, :ciphers) do
      args = [{ :ciphers, ciphers } | args]
    end

    if depth = Keyword.get(options, :depth) do
      args = [{ :depth, depth } | args]
    end

    if versions = Keyword.get(options, :versions) do
      args = [{ :versions, versions } | args]
    end

    if hibernate = Keyword.get(options, :hibernate) do
      args = [{ :hibernate_after, hibernate } | args]
    end

    args = case Keyword.get(options, :reuse) do
      fun when fun |> is_function ->
        [{ :reuse_session, fun } | args]

      true ->
        [{ :reuse_sessions, true } | args]

      nil ->
        args
    end

    if protocols = Keyword.get(options, :advertised_protocols) do
      args = [{ :next_protocols_advertised, protocols } | args]
    end

    args
  end

  @doc """
  Get information about the SSL connection.
  """
  @spec info(t) :: { :ok, list } | { :error, term }
  def info(sock) when sock |> Record.record?(:sslsocket) do
    :ssl.connection_info(sock)
  end

  @doc """
  Get information about the SSL connection, raising if an error occurs.
  """
  @spec info!(t) :: list | no_return
  defbang info(sock)

  @doc """
  Get the certificate of the peer.
  """
  @spec certificate(t) :: { :ok, String.t } | { :error, term }
  def certificate(sock) when sock |> Record.record?(:sslsocket) do
    :ssl.peercert(sock)
  end

  @doc """
  Get the certificate of the peer, raising if an error occurs.
  """
  @spec certificate!(t) :: String.t | no_return
  defbang certificate(sock)

  @doc """
  Get the negotiated next protocol.
  """
  @spec next_protocol(t) :: String.t | nil
  def next_protocol(sock) when sock |> Record.record?(:sslsocket) do
    case :ssl.negotiated_next_protocol(sock) do
      { :ok, protocol } ->
        protocol

      { :error, :next_protocol_not_negotiated } ->
        nil
    end
  end

  @doc """
  Renegotiate the secure connection.
  """
  @spec renegotiate(t) :: :ok | { :error, term }
  def renegotiate(sock) when sock |> Record.record?(:sslsocket) do
    :ssl.renegotiate(sock)
  end

  @doc """
  Renegotiate the secure connection, raising if an error occurs.
  """
  @spec renegotiate!(t) :: :ok | no_return
  defbang renegotiate(sock)
end
