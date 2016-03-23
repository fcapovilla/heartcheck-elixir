defmodule HeartCheck.Executor do
  require Logger

  defp log(message) do
    Logger.info("[HeartCheck] #{message}")
  end

  def recv(tests, ref) do
    recv(tests, Enum.map(tests, fn({name, _}) -> {name, {0 ,{:error, "TIMEOUT"}}} end), ref)
  end

  def recv([], results, _ref) do
    results
  end

  def recv(tests, results, ref) do
    receive do
      {_, {^ref, name, {time, :ok}}} when is_reference(ref) ->
        log("#{inspect(ref)} #{name}: OK - Time: #{time}")
        recv(Keyword.delete(tests, name), Keyword.put(results, name, {time, :ok}), ref)

      {_, {^ref, name, {time, {:error, reason}}}} ->
        log("#{inspect(ref)} #{name}: ERROR: #{inspect(reason)} Time: #{time}")
        recv(Keyword.delete(tests, name), Keyword.put(results, name, {time, {:error, reason}}), ref)

      {^ref, :timeout} ->
        log("#{inspect(ref)} Execution timed out")
        results
    end
  end

  def execute(heartcheck) do
    tests = heartcheck.tests

    ref = make_ref

    task = fn(name) ->
      Task.async fn() ->
        log("(#{inspect(ref)}) Performing #{name}")
        {ref, name, :timer.tc(fn() -> apply(heartcheck, :"perform_test_#{name}", []) end)}
      end
    end

    :timer.send_after(3000, self(), {ref, :timeout})

    tests
    |> Enum.map(fn(t) -> {t, task.(t)} end)
    |> recv(ref)
  end
end
