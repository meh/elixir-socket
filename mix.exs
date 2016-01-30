defmodule Socket.Mixfile do
  use Mix.Project

  def project do
    [ app: :socket,
      version: "0.3.1",
      elixir: "~> 1.0.0 or ~> 1.1.1 or ~> 1.2.0",
      package: package,
      description: "Socket handling library for Elixir" ]
  end

  # Configuration for the OTP application
  def application do
    [ applications: [:crypto, :ssl] ]
  end

  defp package do
    [ contributors: ["meh"],
      licenses: ["WTFPL"],
      links: %{"GitHub" => "https://github.com/meh/elixir-socket"} ]
  end
end
