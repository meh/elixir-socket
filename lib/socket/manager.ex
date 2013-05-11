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
    if pid = Process.whereis(__MODULE__) do
      { :ok, pid }
    else
      case :gen_server.start_link(__MODULE__, [], []) do
        { :ok, pid } = r ->
          Process.register(pid, __MODULE__)
          r

        r -> r
      end
    end
  end

  def stop(_) do
    Process.exit(Process.whereis(__MODULE__), "application stopped")
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
end
