#            DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE
#                    Version 2, December 2004
#
#            DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE
#   TERMS AND CONDITIONS FOR COPYING, DISTRIBUTION AND MODIFICATION
#
#  0. You just DO WHAT THE FUCK YOU WANT TO.

defmodule Socket.Manager do
  use GenServer.Behaviour

  def start_link(_args \\ []) do
    :gen_server.start_link({ :local, :socket }, __MODULE__, [], [])
  end

  def handle_info({ :close, socket }, _state) do
    :inet.close(socket)

    { :noreply, _state }
  end

  def handle_info({ :close, :tcp, socket }, _state) do
    :gen_tcp.close(socket)

    { :noreply, _state }
  end

  def handle_info({ :close, :udp, socket }, _state) do
    :gen_udp.close(socket)

    { :noreply, _state }
  end

  def handle_info({ :close, :sctp, socket }, _state) do
    :gen_sctp.close(socket)

    { :noreply, _state }
  end

  def handle_info({ :close, :sctp, socket, assoc }, _state) do
    :gen_sctp.eof(socket, assoc)

    { :noreply, _state }
  end

  def handle_info({ :close, :ssl, socket }, _state) do
    :ssl.close(socket)

    { :noreply, _state }
  end

  def handle_cast(:stop, _from, _state) do
    { :stop, :normal, _state }
  end
end
