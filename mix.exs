defmodule Socket.Mixfile do
  use Mix.Project

  def project do
    [ app: :socket,
      version: "0.1.1",
      elixir: "~> 0.9.4",
      deps: deps ]
  end

  # Configuration for the OTP application
  def application do
    [ applications: [:finalizer, :crypto, :ssl],
      mod: { Socket.Manager, [] } ]
  end

  # Returns the list of dependencies in the format:
  # { :foobar, "0.1", git: "https://github.com/elixir-lang/foobar.git" }
  defp deps do
    [ { :finalizer, github: "meh/elixir-finalizer" } ]
  end
end
