defmodule Socket.Mixfile do
  use Mix.Project

  def project do
    [ app: :socket,
      version: "0.3.4",
      deps: deps,
      package: package,
      description: "Socket handling library for Elixir" ]
  end

  # Configuration for the OTP application
  def application do
    [ applications: [:crypto, :ssl, :elixir],
      mod: {Socket.App, []} ]
  end

  defp deps do
    [ { :ex_doc, "~> 0.11", only: [:dev] } ]
  end

  defp package do
    [ maintainers: ["meh"],
      licenses: ["WTFPL"],
      links: %{"GitHub" => "https://github.com/meh/elixir-socket"} ]
  end
end
