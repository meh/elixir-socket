defmodule Socket.Mixfile do
  use Mix.Project

  def project do
    [ app: :socket,
      version: "0.2.2",
      elixir: "~> 0.13.2",
      package: package,
      description: "Socket handling library for Elixir" ]
  end

  # Configuration for the OTP application
  def application do
    [ applications: [:crypto, :ssl] ]
  end

  defp package do
    [ contributors: ["meh"],
      license: "WTFPL",
      links: [ { "GitHub", "https://github.com/meh/elixir-socket" } ] ]
  end
end
