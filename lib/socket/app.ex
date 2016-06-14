defmodule Socket.App do
  use Application

  def start(_type, _args) do
    Socket.uris
    {:ok, self}
  end
end
