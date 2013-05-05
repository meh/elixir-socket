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
end
