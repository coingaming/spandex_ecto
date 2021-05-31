defmodule SpandexEcto.EctoLogger do
  @moduledoc """
  A trace builder that can be given to ecto as a logger. It will try to get
  the trace_id and span_id from the caller pid in the case that the particular
  query is being run asynchronously (as in the case of parallel preloads).
  """

  alias Spandex.{
    Span,
    SpanContext,
    Trace
  }

  defmodule Error do
    defexception [:message]
  end

  @empty_query_placeholder "unknown (unsupported ecto adapter?)"

  def trace(log_entry, database) do
    # Put in your own configuration here
    config = Application.get_env(:spandex_ecto, __MODULE__)
    tracer = config[:tracer]
    service = config[:service] || :ecto
    truncate = config[:truncate] || 5000

    caller_pid =
      case Process.get(:"$callers") do
        [caller_process | _] ->
          caller_process

        _ ->
          self()
      end

    now = :os.system_time(:nano_seconds)
    setup(caller_pid, tracer)

    query =
      log_entry
      |> string_query()
      |> String.slice(0, truncate)

    num_rows = num_rows(log_entry)

    queue_time = get_time(log_entry, :queue_time)
    query_time = get_time(log_entry, :query_time)
    decoding_time = get_time(log_entry, :decode_time)

    start = now - (queue_time + query_time + decoding_time)

    tracer.update_span(
      start: start,
      completion_time: now,
      service: service,
      resource: query,
      type: :db,
      sql_query: [
        query: query,
        rows: inspect(num_rows),
        db: database
      ],
      tags: tags(log_entry)
    )

    report_error(tracer, log_entry)

    if queue_time != 0 do
      tracer.start_span("queue")
      tracer.update_span(service: service, start: start, completion_time: start + queue_time)
      tracer.finish_span()
    end

    if query_time != 0 do
      tracer.start_span("run_query")

      tracer.update_span(
        service: service,
        start: start + queue_time,
        completion_time: start + queue_time + query_time
      )

      tracer.finish_span()
    end

    if decoding_time != 0 do
      tracer.start_span("decode")

      tracer.update_span(
        service: service,
        start: start + queue_time + query_time,
        completion_time: now
      )

      tracer.finish_span()
    end

    finish_ecto_trace(caller_pid, tracer)

    log_entry
  end

  defp finish_ecto_trace(caller_pid, tracer) do
    if caller_pid != self() do
      tracer.finish_trace()
    else
      tracer.finish_span()
    end
  end

  defp setup(caller_pid, tracer) when is_pid(caller_pid) do
    if caller_pid == self() do
      if tracer.current_trace_id() do
        tracer.start_span("query")
      end
    else
      {_, trace} = List.keyfind(Process.info(caller_pid)[:dictionary], {:spandex_trace, tracer}, 0)

      case trace do
        %Trace{id: trace_id, stack: [%Span{id: span_id} | _]} ->
          tracer.continue_trace("query", %SpanContext{trace_id: trace_id, parent_id: span_id})
      end
    end

    Logger.metadata(trace_id: tracer.current_trace_id(), span_id: tracer.current_span_id())
  end

  defp report_error(_tracer, %{result: {:ok, _}}), do: :ok

  defp report_error(tracer, %{result: {:error, error}}) do
    tracer.span_error(%Error{message: inspect(error)}, nil)
  end

  defp string_query(%{query: query}) when is_function(query),
    do: Macro.unescape_string(query.() || @empty_query_placeholder)

  defp string_query(%{query: query}) when is_bitstring(query), do: Macro.unescape_string(query)
  defp string_query(%{query: [first | _]}), do: Macro.unescape_string(first)
  defp string_query(_), do: @empty_query_placeholder

  defp num_rows(%{result: {:ok, %{num_rows: num_rows}}}), do: num_rows
  defp num_rows(_), do: 0

  def get_time(log_entry, key) do
    log_entry
    |> Map.get(key)
    |> to_nanoseconds()
  end

  defp to_nanoseconds(time) when is_integer(time), do: System.convert_time_unit(time, :native, :nanosecond)
  defp to_nanoseconds(_time), do: 0

  defp tags(%{params: params}) when is_list(params) do
    param_count =
      params
      |> Enum.count()
      |> to_string()

    [
      param_count: param_count
    ]
  end

  defp tags(_), do: []
end
