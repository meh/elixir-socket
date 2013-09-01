defmodule Socket.Mixfile do
  use Mix.Project

  def project do
    [ app: :socket,
      version: "0.2.0-dev",
      elixir: "~> 0.10.2-dev",
      deps: deps ]
  end

  # Configuration for the OTP application
  def application do
    if System.get_env("ELIXIR_NO_NIF") do
      [ applications: [:crypto, :ssl] ]
    else
      [ applications: [:finalizer, :crypto, :ssl],
        mod: { Socket.Manager, [] } ]
    end
  end

  # Returns the list of dependencies in the format:
  # { :foobar, "0.1", git: "https://github.com/elixir-lang/foobar.git" }
  defp deps do
    if System.get_env("ELIXIR_NO_NIF") do
      []
    else
      [ { :finalizer, github: "meh/elixir-finalizer" } ]
    end
  end
end
