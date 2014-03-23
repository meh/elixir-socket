defmodule Socket.Supervisor do
  use Supervisor.Behaviour

  def start_link do
    :supervisor.start_link(__MODULE__, [])
  end

  def init([]) do
    children = [
      worker(Socket.Manager, [])
    ]
    supervise(children, strategy: :one_for_one)
  end
end
