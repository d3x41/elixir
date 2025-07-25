# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: 2021 The Elixir Team

defmodule Logger.BackendsTest do
  use Logger.Case
  require Logger

  import ExUnit.CaptureIO

  defmodule MyBackend do
    @behaviour :gen_event

    def init({MyBackend, pid}) when is_pid(pid) do
      {:ok, pid}
    end

    def handle_event(event, state) do
      send(state, {:event, event})
      {:ok, state}
    end

    def handle_call(:error, _) do
      raise "oops"
    end

    def handle_info(_msg, state) do
      {:ok, state}
    end

    def code_change(_old_vsn, state, _extra) do
      {:ok, state}
    end

    def terminate(_reason, _state) do
      :ok
    end
  end

  test "add_backend/1 and remove_backend/1" do
    ExUnit.CaptureIO.capture_io(:stderr, fn ->
      assert {:ok, _pid} = Logger.Backends.Internal.add(Logger.Backends.Console)
    end)

    assert Logger.Backends.Internal.add(Logger.Backends.Console) == {:error, :already_present}
    assert :ok = Logger.Backends.Internal.remove(Logger.Backends.Console)
    assert Logger.Backends.Internal.remove(Logger.Backends.Console) == {:error, :not_found}
  end

  test "add_backend/1 with {module, id}" do
    assert {:ok, _} = Logger.Backends.Internal.add({MyBackend, self()})
    assert {:error, :already_present} = Logger.Backends.Internal.add({MyBackend, self()})
    assert :ok = Logger.Backends.Internal.remove({MyBackend, self()})
  end

  test "add_backend/1 with unknown backend" do
    assert {:error, {{:EXIT, {:undef, [_ | _]}}, _}} =
             Logger.Backends.Internal.add({UnknownBackend, self()})
  end

  test "logs or writes to stderr on failed call on async mode" do
    assert {:ok, _} = Logger.Backends.Internal.add({MyBackend, self()})

    assert capture_log(fn ->
             ExUnit.CaptureIO.capture_io(:stderr, fn ->
               :gen_event.call(Logger, {MyBackend, self()}, :error)
               wait_for_handler(Logger, {MyBackend, self()})
             end)
           end) =~
             ~r":gen_event handler {Logger.BackendsTest.MyBackend, #PID<.*>} installed in Logger terminating"

    Logger.flush()
  after
    Logger.Backends.Internal.remove({MyBackend, self()})
  end

  test "logs or writes to stderr on failed call on sync mode" do
    capture_io(:stderr, fn ->
      Logger.configure(sync_threshold: 0)
    end)

    assert {:ok, _} = Logger.Backends.Internal.add({MyBackend, self()})

    assert capture_log(fn ->
             ExUnit.CaptureIO.capture_io(:stderr, fn ->
               :gen_event.call(Logger, {MyBackend, self()}, :error)
               wait_for_handler(Logger, {MyBackend, self()})
             end)
           end) =~
             ~r":gen_event handler {Logger.BackendsTest.MyBackend, #PID<.*>} installed in Logger terminating"

    Logger.flush()
  after
    Logger.configure(sync_threshold: 20)
    Logger.Backends.Internal.remove({MyBackend, :hello})
  end

  test "logs when discarding messages" do
    capture_io(:stderr, fn ->
      assert :ok = Logger.configure(discard_threshold: 5)
    end)

    Logger.Backends.Internal.add({MyBackend, self()})

    capture_log(fn ->
      :sys.suspend(Logger)
      for _ <- 1..10, do: Logger.warning("warning!")
      :sys.resume(Logger)
      Logger.flush()
      send(Logger, {Logger.Backends.Config, :update_counter})
    end)

    assert_receive {:event,
                    {:warning, _,
                     {Logger, "Attempted to log 0 messages, which is below :discard_threshold",
                      _time, _metadata}}}
  after
    :sys.resume(Logger)
    Logger.Backends.Internal.remove({MyBackend, self()})
    assert :ok = Logger.configure(discard_threshold: 500)
  end

  test "restarts Logger.Backends.Config on Logger exits" do
    Logger.Backends.Internal.configure([])

    capture_log(fn ->
      Process.whereis(Logger) |> Process.exit(:kill)
      wait_for_logger()
      wait_for_handler(Logger, Logger.Backends.Config)
    end)
  end
end
