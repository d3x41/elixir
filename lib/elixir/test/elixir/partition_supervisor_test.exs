# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: 2021 The Elixir Team

Code.require_file("test_helper.exs", __DIR__)

defmodule PartitionSupervisorTest do
  use ExUnit.Case, async: true

  describe "child_spec" do
    test "uses the atom name as id" do
      assert Supervisor.child_spec({PartitionSupervisor, name: Foo}, []) == %{
               id: Foo,
               start: {PartitionSupervisor, :start_link, [[name: Foo]]},
               type: :supervisor
             }
    end

    test "uses the via value as id" do
      via = {:via, Foo, {:bar, :baz}}

      assert Supervisor.child_spec({PartitionSupervisor, name: via}, []) == %{
               id: {:bar, :baz},
               start: {PartitionSupervisor, :start_link, [[name: via]]},
               type: :supervisor
             }
    end
  end

  describe "start_link/1" do
    test "on success with atom name", config do
      {:ok, _} =
        PartitionSupervisor.start_link(
          child_spec: DynamicSupervisor,
          name: config.test
        )

      assert PartitionSupervisor.partitions(config.test) == System.schedulers_online()

      refs =
        for _ <- 1..100 do
          ref = make_ref()

          DynamicSupervisor.start_child(
            {:via, PartitionSupervisor, {config.test, ref}},
            {Agent, fn -> ref end}
          )

          ref
        end

      agents =
        for {_, pid, _, _} <- PartitionSupervisor.which_children(config.test),
            {_, pid, _, _} <- DynamicSupervisor.which_children(pid),
            do: Agent.get(pid, & &1)

      assert Enum.sort(refs) == Enum.sort(agents)
    end

    test "on success with via name", config do
      {:ok, _} = Registry.start_link(keys: :unique, name: PartitionRegistry)

      name = {:via, Registry, {PartitionRegistry, config.test}}

      {:ok, _} = PartitionSupervisor.start_link(child_spec: {Agent, fn -> :hello end}, name: name)

      assert PartitionSupervisor.partitions(name) == System.schedulers_online()

      assert Agent.get({:via, PartitionSupervisor, {name, 0}}, & &1) == :hello
    end

    test "with_arguments", config do
      {:ok, _} =
        PartitionSupervisor.start_link(
          child_spec: {Agent, fn -> raise "unused" end},
          with_arguments: fn [_fun], partition -> [fn -> partition end] end,
          partitions: 3,
          name: config.test
        )

      assert PartitionSupervisor.partitions(config.test) == 3

      assert Agent.get({:via, PartitionSupervisor, {config.test, 0}}, & &1) == 0
      assert Agent.get({:via, PartitionSupervisor, {config.test, 1}}, & &1) == 1
      assert Agent.get({:via, PartitionSupervisor, {config.test, 2}}, & &1) == 2

      assert Agent.get({:via, PartitionSupervisor, {config.test, 3}}, & &1) == 0
      assert Agent.get({:via, PartitionSupervisor, {config.test, -1}}, & &1) == 1
    end

    test "raises without name" do
      assert_raise ArgumentError,
                   "the :name option must be given to PartitionSupervisor",
                   fn -> PartitionSupervisor.start_link(child_spec: DynamicSupervisor) end
    end

    test "raises without child_spec" do
      assert_raise ArgumentError,
                   "the :child_spec option must be given to PartitionSupervisor",
                   fn -> PartitionSupervisor.start_link(name: Foo) end
    end

    test "raises on bad partitions" do
      assert_raise ArgumentError,
                   "the :partitions option must be a positive integer, got: 0",
                   fn ->
                     PartitionSupervisor.start_link(
                       name: Foo,
                       child_spec: DynamicSupervisor,
                       partitions: 0
                     )
                   end
    end

    test "raises on bad with_arguments" do
      assert_raise ArgumentError,
                   ~r"the :with_arguments option must be a function that receives two arguments",
                   fn ->
                     PartitionSupervisor.start_link(
                       name: Foo,
                       child_spec: DynamicSupervisor,
                       with_arguments: 123
                     )
                   end
    end

    test "raises with bad auto_shutdown" do
      assert_raise ArgumentError,
                   "the :auto_shutdown option must be :never, got: :any_significant",
                   fn ->
                     PartitionSupervisor.start_link(
                       child_spec: DynamicSupervisor,
                       name: Foo,
                       auto_shutdown: :any_significant
                     )
                   end
    end
  end

  describe "stop/1" do
    test "is synchronous", config do
      {:ok, _} =
        PartitionSupervisor.start_link(
          child_spec: {Agent, fn -> %{} end},
          name: config.test
        )

      assert PartitionSupervisor.stop(config.test) == :ok
      assert Process.whereis(config.test) == nil
    end
  end

  describe "partitions/1" do
    test "raises noproc for unknown atom partition supervisor" do
      assert {:noproc, _} = catch_exit(PartitionSupervisor.partitions(:unknown))
    end

    test "raises noproc for unknown via partition supervisor", config do
      {:ok, _} = Registry.start_link(keys: :unique, name: config.test)
      via = {:via, Registry, {config.test, :unknown}}
      assert {:noproc, _} = catch_exit(PartitionSupervisor.partitions(via))
    end
  end

  describe "resize!/1" do
    test "resizes the number of children", config do
      {:ok, _} =
        PartitionSupervisor.start_link(
          child_spec: {Agent, fn -> %{} end},
          name: config.test,
          partitions: 8
        )

      for range <- [8..0//1, 0..8//1, Enum.shuffle(0..8)], i <- range do
        PartitionSupervisor.resize!(config.test, i)
        assert PartitionSupervisor.partitions(config.test) == i

        assert PartitionSupervisor.count_children(config.test) ==
                 %{active: i, specs: 8, supervisors: 0, workers: 8}

        # Assert that we can still query across all range,
        # but they are routed properly, as long as we have
        # a single partition.
        children =
          for partition <- 0..7, i != 0, uniq: true do
            GenServer.whereis({:via, PartitionSupervisor, {config.test, partition}})
          end

        assert length(children) == i
      end
    end

    test "raises on lookup after resizing to zero", config do
      {:ok, _} =
        PartitionSupervisor.start_link(
          child_spec: {Agent, fn -> %{} end},
          name: config.test,
          partitions: 8
        )

      assert PartitionSupervisor.resize!(config.test, 0) == 8

      assert_raise ArgumentError, ~r"has zero partitions", fn ->
        GenServer.whereis({:via, PartitionSupervisor, {config.test, 0}})
      end

      assert PartitionSupervisor.resize!(config.test, 8) == 0
    end

    test "raises if trying to increase the number of partitions", config do
      {:ok, _} =
        PartitionSupervisor.start_link(
          child_spec: {Agent, fn -> %{} end},
          name: config.test,
          partitions: 8
        )

      assert_raise ArgumentError,
                   "the number of partitions to resize to must be a number between 0 and 8, got: 9",
                   fn -> PartitionSupervisor.resize!(config.test, 9) end
    end
  end

  describe "which_children/1" do
    test "returns all partitions", config do
      {:ok, _} =
        PartitionSupervisor.start_link(
          child_spec: {Agent, fn -> %{} end},
          name: config.test
        )

      assert PartitionSupervisor.partitions(config.test) == System.schedulers_online()

      children =
        config.test
        |> PartitionSupervisor.which_children()
        |> Enum.sort()

      for {child, partition} <- Enum.zip(children, 0..(System.schedulers_online() - 1)) do
        via = {:via, PartitionSupervisor, {config.test, partition}}
        assert child == {partition, GenServer.whereis(via), :worker, [Agent]}
      end
    end
  end

  describe "count_children/1" do
    test "with workers", config do
      {:ok, _} =
        PartitionSupervisor.start_link(
          child_spec: {Agent, fn -> %{} end},
          name: config.test
        )

      partitions = System.schedulers_online()

      assert PartitionSupervisor.count_children(config.test) ==
               %{active: partitions, specs: partitions, supervisors: 0, workers: partitions}
    end

    test "with supervisors", config do
      {:ok, _} =
        PartitionSupervisor.start_link(
          child_spec: DynamicSupervisor,
          name: config.test
        )

      partitions = System.schedulers_online()

      assert PartitionSupervisor.count_children(config.test) ==
               %{active: partitions, specs: partitions, supervisors: partitions, workers: 0}
    end

    test "raises noproc for unknown partition supervisor" do
      assert {:noproc, _} = catch_exit(PartitionSupervisor.count_children(:unknown))
    end
  end
end
