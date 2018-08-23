defmodule SpandexEcto.MixProject do
  use Mix.Project

  def project do
    [
      app: :spandex_ecto,
      description: description(),
      version: "0.1.0",
      elixir: "~> 1.7",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      package: package()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp package do
    [
      name: :spandex_ecto,
      maintainers: ["Zachary Daniel"],
      licenses: ["MIT License"],
      links: %{"GitHub" => "https://github.com/spandex-project/spandex_ecto"}
    ]
  end

  defp description() do
    """
    Tools for integrating Ecto with Spandex.
    """
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ex_doc, ">= 0.0.0", only: :dev}
    ]
  end
end
