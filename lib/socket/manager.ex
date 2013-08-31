#            DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE
#                    Version 2, December 2004
#
#            DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE
#   TERMS AND CONDITIONS FOR COPYING, DISTRIBUTION AND MODIFICATION
#
#  0. You just DO WHAT THE FUCK YOU WANT TO.

defmodule Socket.Manager do
  use Application.Behaviour
  use GenServer.Behaviour

  def start(_, _) do
    :gen_server.start_link({ :local, __MODULE__ }, __MODULE__, [], []) do
  end

  def stop(_) do
    :gen_server.cast(__MODULE__, :stop)
  end

  def handle_info({ :close, socket }, state) do
    :inet.close(socket)

    { :noreply, state }
  end

  def handle_info({ :close, :tcp, socket }, state) do
    :gen_tcp.close(socket)

    { :noreply, state }
  end

  def handle_info({ :close, :udp, socket }, state) do
    :gen_udp.close(socket)

    { :noreply, state }
  end

  def handle_info({ :close, :sctp, socket }, state) do
    :gen_sctp.close(socket)

    { :noreply, state }
  end

  def handle_info({ :close, :sctp, socket, assoc }, state) do
    :gen_sctp.eof(socket, assoc)

    { :noreply, state }
  end

  def handle_info({ :close, :ssl, socket }, state) do
    :ssl.close(socket)

    { :noreply, state }
  end

  def handle_cast(:stop, _from, _state) do
    { :stop, :normal, _state }
  end
end
