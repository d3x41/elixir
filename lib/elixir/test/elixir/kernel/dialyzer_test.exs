# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: 2021 The Elixir Team
# SPDX-FileCopyrightText: 2012 Plataformatec

Code.require_file("../test_helper.exs", __DIR__)

defmodule Kernel.DialyzerTest do
  use ExUnit.Case, async: true

  @moduletag :dialyzer
  @moduletag :require_ast
  import PathHelpers

  setup_all do
    dir = tmp_path("dialyzer")
    File.rm_rf!(dir)
    File.mkdir_p!(dir)

    plt =
      dir
      |> Path.join("base_plt")
      |> String.to_charlist()

    # Some OSs (like Windows) do not provide the HOME environment variable.
    if !System.get_env("HOME") do
      System.put_env("HOME", System.user_home())
    end

    # Add a few key Elixir modules for types and macro functions
    mods = [
      :elixir,
      :elixir_env,
      :elixir_erl_pass,
      :maps,
      :sets,
      ArgumentError,
      Atom,
      Code,
      Enum,
      Exception,
      ExUnit.AssertionError,
      ExUnit.Assertions,
      IO,
      Kernel,
      Kernel.Utils,
      List,
      Macro,
      Macro.Env,
      MapSet,
      Module,
      Protocol,
      String,
      String.Chars,
      Task,
      Task.Supervisor
    ]

    files = Enum.map(mods, &:code.which/1)
    dialyzer_run(analysis_type: :plt_build, output_plt: plt, apps: [:erts], files: files)

    # Compile Dialyzer fixtures
    source_files = Path.wildcard(Path.join(fixture_path("dialyzer"), "*"))

    {:ok, _, _} =
      Kernel.ParallelCompiler.compile_to_path(source_files, dir, return_diagnostics: true)

    {:ok, [base_dir: dir, base_plt: plt]}
  end

  setup context do
    dir = String.to_charlist(context.tmp_dir)

    plt =
      dir
      |> Path.join("plt")
      |> String.to_charlist()

    File.cp!(context.base_plt, plt)
    warnings = Map.get(context, :warnings, [])

    dialyzer = [
      analysis_type: :succ_typings,
      check_plt: false,
      files_rec: [dir],
      plts: [plt],
      warnings: warnings
    ]

    {:ok, [outdir: dir, dialyzer: dialyzer]}
  end

  @moduletag :tmp_dir

  @tag warnings: [:specdiffs]
  test "no warnings on specdiffs", context do
    copy_beam!(context, Dialyzer.RemoteCall)
    assert_dialyze_no_warnings!(context)
  end

  test "no warnings on valid remote calls", context do
    copy_beam!(context, Dialyzer.RemoteCall)
    assert_dialyze_no_warnings!(context)
  end

  test "no warnings on rewrites", context do
    copy_beam!(context, Dialyzer.Rewrite)
    assert_dialyze_no_warnings!(context)
  end

  test "no warnings on raise", context do
    copy_beam!(context, Dialyzer.Raise)
    assert_dialyze_no_warnings!(context)
  end

  test "no warnings on macrocallback", context do
    copy_beam!(context, Dialyzer.Macrocallback)
    copy_beam!(context, Dialyzer.Macrocallback.Impl)
    assert_dialyze_no_warnings!(context)
  end

  test "no warnings on callback", context do
    copy_beam!(context, Dialyzer.Callback)
    copy_beam!(context, Dialyzer.Callback.ImplAtom)
    copy_beam!(context, Dialyzer.Callback.ImplList)
    assert_dialyze_no_warnings!(context)
  end

  test "no warnings on and/2 and or/2", context do
    copy_beam!(context, Dialyzer.BooleanCheck)
    assert_dialyze_no_warnings!(context)
  end

  test "no warnings on cond", context do
    copy_beam!(context, Dialyzer.Cond)
    assert_dialyze_no_warnings!(context)
  end

  test "no warnings on for comprehensions with bitstrings", context do
    copy_beam!(context, Dialyzer.ForBitstring)
    assert_dialyze_no_warnings!(context)
  end

  test "no warnings on for falsy check that always boolean", context do
    copy_beam!(context, Dialyzer.ForBooleanCheck)
    assert_dialyze_no_warnings!(context)
  end

  test "no warnings on with/else", context do
    copy_beam!(context, Dialyzer.With)
    assert_dialyze_no_warnings!(context)
  end

  test "no warnings on with when else has a no_return type", context do
    copy_beam!(context, Dialyzer.WithNoReturn)
    assert_dialyze_no_warnings!(context)
  end

  test "no warnings on with when multiple else clauses and one is a no_return", context do
    copy_beam!(context, Dialyzer.WithThrowingElse)
    assert_dialyze_no_warnings!(context)
  end

  test "no warnings on defmacrop", context do
    copy_beam!(context, Dialyzer.Defmacrop)
    assert_dialyze_no_warnings!(context)
  end

  test "no warnings on try", context do
    copy_beam!(context, Dialyzer.Try)
    assert_dialyze_no_warnings!(context)
  end

  test "no warning on is_struct/2", context do
    copy_beam!(context, Dialyzer.IsStruct)
    assert_dialyze_no_warnings!(context)
  end

  test "no warning on ExUnit assertions", context do
    copy_beam!(context, Dialyzer.Assertions)
    assert_dialyze_no_warnings!(context)
  end

  test "no warning due to opaqueness edge cases", context do
    copy_beam!(context, Dialyzer.Opaqueness)
    assert_dialyze_no_warnings!(context)
  end

  defp copy_beam!(context, module) do
    name = "#{module}.beam"
    File.cp!(Path.join(context.base_dir, name), Path.join(context.outdir, name))
  end

  defp assert_dialyze_no_warnings!(context) do
    case dialyzer_run(context.dialyzer) do
      [] ->
        :ok

      warnings ->
        formatted = for warn <- warnings, do: [:dialyzer.format_warning(warn), ?\n]
        formatted |> IO.chardata_to_string() |> flunk()
    end
  end

  defp dialyzer_run(opts) do
    try do
      :dialyzer.run(opts)
    catch
      :throw, {:dialyzer_error, chardata} ->
        raise "dialyzer error: " <> IO.chardata_to_string(chardata)
    end
  end
end
