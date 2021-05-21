defmodule SpandexEcto.TelemetryAdapter do
  @moduledoc """
  This module provides event handler functions for telemetry
  """

  alias SpandexEcto.EctoLogger

  #  this is for ecto_sql 3.0.x
  def handle_event([app_name, repo_name, :query], total_time, log_entry, config) when is_integer(total_time) do
    EctoLogger.trace(log_entry, "#{repo_name}_database", service(config, app_name, repo_name))
  end

  # This is for ecto_sql >= 3.1
  def handle_event([app_name, repo_name, :query], measurements, metadata, config) when is_map(measurements) do
    log_entry = %{
      query: metadata.query,
      source: metadata.source,
      params: metadata.params,
      query_time: Map.get(measurements, :query_time, 0),
      decode_time: Map.get(measurements, :decode_time, 0),
      queue_time: Map.get(measurements, :queue_time, 0),
      result: wrap_result(metadata.result)
    }

    EctoLogger.trace(log_entry, "#{repo_name}_database", service(config, app_name, repo_name))
  end

  def handle_event(event_name, measurements, log_entry, config) when is_list(event_name) do
    event_name
    |> tl()
    |> handle_event(measurements, log_entry, config)
  end

  defp wrap_result(result) when is_atom(result), do: {result, "n/a"}
  defp wrap_result(result), do: result

  defp service(config, app_name, repo_name) do
    config[:service] || String.to_atom("#{app_name}_#{repo_name}")
  end
end
