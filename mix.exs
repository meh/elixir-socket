defmodule Socket.Mixfile do
  use Mix.Project

  def project do
    [ app: :socket,
      version: "0.2.0-dev",
      elixir: "~> 0.12.4",
      deps: deps ]
  end

  def application do
    if System.get_env("ELIXIR_NO_NIF") do
      [ applications: [:crypto, :ssl] ]
    else
      [ applications: [:finalizer, :crypto, :ssl],
        mod: { Socket.Manager, [] } ]
    end
  end

  defp deps do
    if System.get_env("ELIXIR_NO_NIF") do
      []
    else
      [ { :finalizer, github: "meh/elixir-finalizer" } ]
    end
  end
end
