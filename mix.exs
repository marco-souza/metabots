defmodule Metabots.MixProject do
  use Mix.Project

  def project do
    [
      apps_path: "apps",
      version: "0.1.0",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Dependencies listed here are available only for this
  # project and cannot be accessed from applications inside
  # the apps folder.
  #
  # Run "mix help deps" for examples and options.
  defp deps do
    []
  end

  def observer do
    Mix.ensure_application!(:wx)
    Mix.ensure_application!(:runtime_tools)
    Mix.ensure_application!(:observer)

    :observer.start()
  end
end
