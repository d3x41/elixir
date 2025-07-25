# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: 2021 The Elixir Team
# SPDX-FileCopyrightText: 2012 Plataformatec

Code.require_file("../../test_helper.exs", __DIR__)

defmodule Mix.Tasks.TestTest do
  use MixTest.Case

  describe "ex_unit_opts/1" do
    test "returns ex unit options" do
      assert filtered_ex_unit_opts(unknown: "ok", seed: 13) == [seed: 13]
    end

    test "returns includes and excludes" do
      included = [include: [:focus, key: "val"]]
      assert filtered_ex_unit_opts(include: "focus", include: "key:val") == included

      excluded = [exclude: [:focus, key: "val"]]
      assert filtered_ex_unit_opts(exclude: "focus", exclude: "key:val") == excluded
    end

    test "translates :only into includes and excludes" do
      assert filtered_ex_unit_opts(only: "focus") == [include: [:focus], exclude: [:test]]

      only = [include: [:focus, :special], exclude: [:test]]
      assert filtered_ex_unit_opts(only: "focus", include: "special") == only
    end

    test "translates :name_pattern into includes and excludes" do
      assert [include: [test: hello_regex, test: world_regex], exclude: [:test]] =
               filtered_ex_unit_opts(name_pattern: ~r/hello/, name_pattern: ~r/world/)

      assert Regex.match?(hello_regex, "hello")
      refute Regex.match?(hello_regex, "world")
      refute Regex.match?(world_regex, "hello")
      assert Regex.match?(world_regex, "world")
    end

    test "translates :color into list containing an enabled key-value pair" do
      assert filtered_ex_unit_opts(color: false) == [colors: [enabled: false]]
      assert filtered_ex_unit_opts(color: true) == [colors: [enabled: true]]
    end

    test "translates :formatter into list of modules" do
      assert filtered_ex_unit_opts(formatter: "A.B") == [formatters: [A.B]]
    end

    test "accepts custom :exit_status" do
      assert {:exit_status, 5} in ex_unit_opts(exit_status: 5, failures_manifest_path: "foo.bar")
    end

    test "includes some default options" do
      assert ex_unit_opts(failures_manifest_path: "foo.bar") == [
               autorun: false,
               exit_status: 2,
               failures_manifest_path: "foo.bar"
             ]
    end

    defp ex_unit_opts(opts) do
      {ex_unit_opts, _allowed_files} = Mix.Tasks.Test.process_ex_unit_opts(opts)
      ex_unit_opts
    end

    defp filtered_ex_unit_opts(opts) do
      opts
      |> Keyword.put(:failures_manifest_path, "foo.bar")
      |> ex_unit_opts()
      |> Keyword.drop([:failures_manifest_path, :autorun, :exit_status])
    end
  end

  describe "--stale" do
    test "runs all tests for first run, then none on second" do
      in_fixture("test_stale", fn ->
        assert_stale_run_output("2 tests, 0 failures")

        assert_stale_run_output("""
        No stale tests
        """)
      end)
    end

    test "runs tests that depend on modified modules" do
      in_fixture("test_stale", fn ->
        assert_stale_run_output("2 tests, 0 failures")

        set_all_mtimes()
        force_recompilation("lib/b.ex")

        assert_stale_run_output("1 test, 0 failures")

        set_all_mtimes()
        force_recompilation("lib/a.ex")

        assert_stale_run_output("2 tests, 0 failures")
      end)
    end

    test "doesn't write manifest when there are failures" do
      in_fixture("test_stale", fn ->
        assert_stale_run_output("2 tests, 0 failures")

        set_all_mtimes()

        File.write!("lib/b.ex", """
        defmodule B do
          def f, do: :error
        end
        """)

        assert_stale_run_output("1 test, 1 failure")

        assert_stale_run_output("1 test, 1 failure")
      end)
    end

    test "runs tests that have changed" do
      in_fixture("test_stale", fn ->
        assert_stale_run_output("2 tests, 0 failures")

        set_all_mtimes()
        File.touch!("test/a_test_stale.exs")

        assert_stale_run_output("1 test, 0 failures")
      end)
    end

    test "runs tests that have changed test_helpers" do
      in_fixture("test_stale", fn ->
        assert_stale_run_output("2 tests, 0 failures")

        set_all_mtimes()
        File.touch!("test/test_helper.exs")

        assert_stale_run_output("2 tests, 0 failures")
      end)
    end

    test "runs all tests no matter what with --force" do
      in_fixture("test_stale", fn ->
        assert_stale_run_output("2 tests, 0 failures")

        assert_stale_run_output(~w[--force], "2 tests, 0 failures")
      end)
    end
  end

  describe "--cover" do
    @describetag :cover
    test "reports the coverage of each app's modules in an umbrella" do
      in_fixture("umbrella_test", fn ->
        # This fixture by default results in coverage above the default threshold
        # which should result in an exit status of 0.
        assert {output, 0} = mix_code(["test", "--cover"])
        assert output =~ "4 tests, 0 failures"

        # For bar, we do regular --cover and also test protocols
        assert output =~ """
               Generating cover results ...

               | Percentage | Module                 |
               |------------|------------------------|
               |    100.00% | Bar.Protocol           |
               |    100.00% | Bar.Protocol.BitString |
               |------------|------------------------|
               |    100.00% | Total                  |
               """

        assert output =~ "1 test, 0 failures"

        # For foo, we do regular --cover and test it does not include bar
        assert output =~ """
               Generating cover results ...

               | Percentage | Module     |
               |------------|------------|
               |    100.00% | Foo        |
               |------------|------------|
               |    100.00% | Total      |
               """

        # We skip a test in bar to force coverage below the default threshold
        # which should result in an exit status of 1.
        assert {output, code} = mix_code(["test", "--cover", "--exclude", "maybe_skip"])

        assert output =~ """
               Coverage test failed, threshold not met:

                   Coverage:    0.00%
                   Threshold:  90.00%
               """

        assert code == 3
      end)
    end

    test "supports unified reports by using test.coverage" do
      in_fixture("umbrella_test", fn ->
        assert mix(["test", "--export-coverage", "default", "--cover"]) =~
                 "Run \"mix test.coverage\" once all exports complete"

        assert mix(["test.coverage"]) =~ """
               Importing cover results: apps/bar/cover/default.coverdata
               Importing cover results: apps/foo/cover/default.coverdata

               | Percentage | Module                 |
               |------------|------------------------|
               |    100.00% | Bar                    |
               |    100.00% | Bar.Ignore             |
               |    100.00% | Bar.Protocol           |
               |    100.00% | Bar.Protocol.BitString |
               |    100.00% | Foo                    |
               |------------|------------------------|
               |    100.00% | Total                  |
               """
      end)
    end
  end

  describe "--failed" do
    test "loads only files with failures and runs just the failures" do
      in_fixture("test_failed", fn ->
        loading_only_passing_test_msg = "loading OnlyPassingTest"

        # Run `mix test` once to record failures...
        output = mix(["test"])
        assert output =~ loading_only_passing_test_msg
        assert output =~ "4 tests, 2 failures"

        # `mix test --failed` runs only failed tests and avoids loading files with no failures
        output = mix(["test", "--failed"])
        refute output =~ loading_only_passing_test_msg
        assert output =~ "2 tests, 2 failures"

        # `mix test --failed` can be applied to a directory or file
        output = mix(["test", "test/passing_and_failing_test_failed.exs", "--failed"])
        assert output =~ "1 test, 1 failure"

        # Plus line
        output = mix(["test", "test/passing_and_failing_test_failed.exs:5", "--failed"])
        assert output =~ "1 test, 1 failure"

        if windows?() do
          output = mix(["test", "test\\passing_and_failing_test_failed.exs:5", "--failed"])
          assert output =~ "1 test, 1 failure"
        end

        # `--failed` composes with an `--only` filter by running the intersection.
        # Of the failing tests, 1 is tagged with `@tag :foo`.
        # Of the passing tests, 1 is tagged with `@tag :foo`.
        # But only the failing test with that tag should run.
        output = mix(["test", "--failed", "--only", "foo"])
        assert output =~ "1 test, 1 failure (1 excluded)"

        # Run again to give it a chance to record as passed
        System.put_env("PASS_FAILING_TESTS", "true")
        assert mix(["test", "--failed"]) =~ "2 tests, 0 failures"

        # Nothing should get run if we try it again since everything is passing.
        assert mix(["test", "--failed"]) =~ "There are no tests to run"

        # When everything is passing and a file is passed, we return the proper message
        output = mix(["test", "test/passing_and_failing_test_failed.exs", "--failed"])
        assert output =~ "There are no tests to run"
        refute output =~ "does not match"

        # `--failed` and `--stale` cannot be combined
        output = mix(["test", "--failed", "--stale"])
        assert output =~ "Combining --failed and --stale is not supported"
      end)
    after
      System.delete_env("PASS_FAILING_TESTS")
    end

    test "marks the whole suite as failed on compilation error" do
      in_fixture("test_failed", fn ->
        File.write!("test/passing_and_failing_test_failed.exs", "raise ~s(oops)")

        output = mix(["test"])
        assert output =~ "** (RuntimeError) oops"

        output = mix(["test", "--failed"])
        assert output =~ "** (RuntimeError) oops"
      end)
    end
  end

  describe "--listen-on-stdin" do
    test "runs tests after input" do
      in_fixture("test_stale", fn ->
        port = mix_port(~w[test --stale --listen-on-stdin])

        assert receive_until_match(port, "0 failures", "") =~ "2 tests"

        Port.command(port, "\n")

        assert receive_until_match(port, "Restarting...", "") =~ "Restarting..."
      end)
    end
  end

  describe "--partitions" do
    @tag :cover
    test "splits tests into partitions (with coverage)" do
      in_fixture("test_stale", fn ->
        assert mix(["test", "--partitions", "3", "--cover"], [{"MIX_TEST_PARTITION", "1"}]) =~
                 "1 test, 0 failures"

        assert mix(["test", "--partitions", "3", "--cover"], [{"MIX_TEST_PARTITION", "2"}]) =~
                 "1 test, 0 failures"

        assert mix(["test", "--partitions", "3", "--cover"], [{"MIX_TEST_PARTITION", "3"}]) =~
                 "There are no tests to run"

        assert File.regular?("cover/1.coverdata")
        assert File.regular?("cover/2.coverdata")
        refute File.regular?("cover/3.coverdata")

        assert mix(["test.coverage"]) == """
               Importing cover results: cover/1.coverdata
               Importing cover results: cover/2.coverdata

               | Percentage | Module     |
               |------------|------------|
               |    100.00% | A          |
               |    100.00% | B          |
               |------------|------------|
               |    100.00% | Total      |

               Generated HTML coverage results in \"cover\" directory
               """
      end)
    end

    test "raises when no partition is given even with Mix.shell() change" do
      in_fixture("test_stale", fn ->
        File.write!("test/test_helper.exs", """
        Mix.shell(Mix.Shell.Process)
        ExUnit.start()
        """)

        assert_run_output(
          ["--partitions", "4"],
          "The MIX_TEST_PARTITION environment variable must be set"
        )
      end)
    end

    test "do not raise if partitions flag is set to 1 and no partition given" do
      in_fixture("test_stale", fn ->
        assert mix(["test", "--partitions", "1"], []) =~
                 "2 tests, 0 failures"

        assert mix(["test", "--partitions", "1"], [{"MIX_TEST_PARTITION", ""}]) =~
                 "2 tests, 0 failures"

        assert mix(["test", "--partitions", "1"], [{"MIX_TEST_PARTITION", "1"}]) =~
                 "2 tests, 0 failures"
      end)
    end

    test "raise if partitions is set to non-positive value" do
      in_fixture("test_stale", fn ->
        File.write!("test/test_helper.exs", """
        Mix.shell(Mix.Shell.Process)
        ExUnit.start()
        """)

        assert_run_output(
          ["--partitions", "0"],
          "--partitions : expected to be positive integer, got 0"
        )

        assert_run_output(
          ["--partitions", "-1"],
          "--partitions : expected to be positive integer, got -1"
        )
      end)
    end

    test "runs after_suite with partitions with no tests" do
      in_fixture("test_stale", fn ->
        File.write!("test/test_helper.exs", """
        ExUnit.after_suite(fn _stats -> IO.puts("AFTER SUITE") end)
        ExUnit.start()
        """)

        assert mix(["test", "--partitions", "3"], [{"MIX_TEST_PARTITION", "3"}]) =~ """
               AFTER SUITE
               There are no tests to run
               """
      end)
    end
  end

  describe "logs and errors" do
    test "logs test absence for a project with no test paths" do
      in_fixture("test_stale", fn ->
        File.rm_rf!("test")
        assert_run_output("There are no tests to run")

        File.mkdir_p!("test")
        File.write!("test/test_helper.exs", "ExUnit.start()")
        assert_run_output("There are no tests to run")
      end)
    end

    test "raises when no test runs even with Mix.shell() change" do
      in_fixture("test_stale", fn ->
        File.write!("test/test_helper.exs", """
        Mix.shell(Mix.Shell.Process)
        ExUnit.start()
        """)

        assert_run_output(
          ["--only", "unknown"],
          "The --only option was given to \"mix test\" but no test was executed"
        )
      end)
    end

    test "runs multiple test files if line numbers are given" do
      in_fixture("test_stale", fn ->
        assert_run_output(
          ["test/a_test_stale.exs:2", "test/b_test_stale.exs:4"],
          """
          Excluding tags: [:test]
          Including tags: [location: {"test/a_test_stale.exs", 2}, location: {"test/b_test_stale.exs", 4}]
          """
        )
      end)
    end

    test "umbrella with file path" do
      in_fixture("umbrella_test", fn ->
        # Run false positive test first so at least the code is compiled
        # and we can perform more aggressive assertions later
        output = mix(["test", "apps/unknown_app/test"])

        assert output =~ """
               ==> bar
               Paths given to "mix test" did not match any directory/file: apps/unknown_app/test
               """

        assert output =~ """
               ==> foo
               Paths given to "mix test" did not match any directory/file: apps/unknown_app/test
               """

        output = mix(["test", "apps/bar/test/bar_tests.exs"])

        assert output =~ "==> bar"
        assert output =~ "...."

        refute output =~ "==> foo"
        refute output =~ "Paths given to \"mix test\" did not match any directory/file"

        output = mix(["test", "./apps/bar/test/bar_tests.exs"])

        assert output =~ "==> bar"
        assert output =~ "...."

        refute output =~ "==> foo"
        refute output =~ "Paths given to \"mix test\" did not match any directory/file"

        output = mix(["test", Path.expand("apps/bar/test/bar_tests.exs")])

        assert output =~ "==> bar"
        assert output =~ "...."

        refute output =~ "==> foo"
        refute output =~ "Paths given to \"mix test\" did not match any directory/file"

        output = mix(["test", "apps/bar/test/bar_tests.exs:10"])

        assert output =~ "==> bar"

        assert output =~ """
               Excluding tags: [:test]
               Including tags: [location: {"test/bar_tests.exs", 10}]

               .
               """

        refute output =~ "==> foo"
        refute output =~ "Paths given to \"mix test\" did not match any directory/file"

        casing =
          if windows?() do
            "apps\\bar\\test\\bar_tests.exs:5"
          else
            "apps/bar/test/bar_tests.exs:5"
          end

        output = mix(["test", "apps/foo/test/foo_tests.exs:9", casing])

        assert output =~ """
               Excluding tags: [:test]
               Including tags: [location: {"test/foo_tests.exs", 9}]
               """

        assert output =~ "1 test, 0 failures\n"

        assert output =~ """
               Excluding tags: [:test]
               Including tags: [location: {"test/bar_tests.exs", 5}]
               """

        assert output =~ "1 test, 0 failures (3 excluded)\n"
      end)
    end
  end

  describe "--warnings-as-errors" do
    test "fail with exit status 1 if warning in tests but tests pass" do
      in_fixture("test_stale", fn ->
        msg =
          "Test suite aborted after successful execution due to warnings while using the --warnings-as-errors option"

        refute mix(["test", "--warnings-as-errors"]) =~ msg

        File.write!("lib/warning.ex", """
        unused_compile_var = 1
        """)

        File.write!("test/warning_test_stale.exs", """
        defmodule WarningTest do
          use ExUnit.Case

          test "warning" do
            unused_test_var = 1
          end
        end
        """)

        {output, exit_status} =
          mix_code(["test", "--warnings-as-errors", "test/warning_test_stale.exs"])

        assert output =~ "variable \"unused_compile_var\" is unused"
        assert output =~ "variable \"unused_test_var\" is unused"
        assert output =~ msg
        assert exit_status == 1
      end)
    end

    test "fail with --exit-status + 1 if warning in tests and tests fail" do
      in_fixture("test_stale", fn ->
        File.write!("test/warning_test_warnings_as_errors_and_failures.exs", """
        defmodule WarningsAsErrorsAndFailuresTest do
          use ExUnit.Case

          test "warning and failure" do
            unused_test_var = 1
            assert false
          end
        end
        """)

        {output, exit_status} =
          mix_code([
            "test",
            "--warnings-as-errors",
            "--exit-status",
            "42",
            "test/warning_test_warnings_as_errors_and_failures.exs"
          ])

        assert output =~ "variable \"unused_test_var\" is unused"
        assert output =~ "1 failure"

        assert exit_status == 43
      end)
    end

    test "mark failed tests" do
      in_fixture("test_failed", fn ->
        File.write!("test/warning_test_failed.exs", """
        defmodule WarningTest do
          use ExUnit.Case

          test "warning" do
            unused_var = 123
          end
        end
        """)

        output = mix(["test", "--warnings-as-errors"])
        assert output =~ "2 failures"
        refute output =~ "Test suite aborted after successful execution"
        output = mix(["test", "--failed"])
        assert output =~ "2 failures"
      end)
    end
  end

  describe "--exit-status" do
    test "returns custom exit status" do
      in_fixture("test_failed", fn ->
        {output, exit_status} = mix_code(["test", "--exit-status", "5"])
        assert output =~ "2 failures"
        assert exit_status == 5
      end)
    end
  end

  describe "--max-requires" do
    test "runs tests with --max-requires 1" do
      # this is only a smoke test to ensure that tests run with --max-requires 1
      # it does not test the concurrency behavior
      in_fixture("test_stale", fn ->
        output = mix(["test", "--max-requires", "1"])
        assert output =~ "0 failures"
      end)
    end
  end

  describe "test_load_filters and test_ignore_filters" do
    test "warns for files that are not loaded and don't match test_ignore_filters" do
      in_tmp("test_warn", fn ->
        File.write!("mix.exs", """
        defmodule TestWarn.MixProject do
          use Mix.Project

          def project do
            [
              app: :test_warn,
              version: "0.0.1",
              test_load_filters: [~r/.*_tests\.exs/],
              test_ignore_filters: [
                "test/test_helper.exs",
                ~r/ignored_regex/,
                fn file -> file == "test/ignored_file.exs" end
              ]
            ]
          end
        end
        """)

        File.mkdir!("test")

        File.write!("test/a_tests.exs", """
        defmodule ATests do
          use ExUnit.Case

          test "dummy" do
            assert true
          end
        end
        """)

        File.write!("test/test_helper.exs", "ExUnit.start()")
        File.touch("test/a_missing.exs")
        File.touch("test/a_tests.ex")
        File.touch("test/ignored_file.exs")
        File.touch("test/ignored_regex.exs")
        File.write!("test/other_file.txt", "this is not a test file")

        output = mix(["test"])

        # This test relies on the files present in the test_warn fixture.
        #
        # We test that we don't warn about a_tests.exs, as it already matches the load pattern.
        # Similarly, we ignore the empty but present ignored_file.exs and ignored_regex.exs.
        # other_file.txt does not match the test_pattern and is ignored from the beginning.
        #
        # Therefore, we expect to get a warning for a_missing.exs and a_tests.ex.
        assert output =~ """
               the following files do not match any of the configured `:test_load_filters` / `:test_ignore_filters`:

               test/a_missing.exs
               test/a_tests.ex

               This might indicate a typo\
               """

        # the dummy test ran successfully
        assert output =~ "1 test, 0 failures"
      end)
    end

    test "does not warn when test_ignore_filters are disabled" do
      in_tmp("test_warn", fn ->
        File.write!("mix.exs", """
        defmodule TestWarn.MixProject do
          use Mix.Project

          def project do
            [
              app: :test_warn,
              version: "0.0.1",
              test_load_filters: [~r/.*_tests\.exs/],
              test_ignore_filters: [fn _ -> true end]
            ]
          end
        end
        """)

        File.mkdir!("test")

        File.write!("test/a_tests.exs", """
        defmodule ATests do
          use ExUnit.Case

          test "dummy" do
            assert true
          end
        end
        """)

        File.write!("test/test_helper.exs", "ExUnit.start()")
        File.touch("test/a_missing.exs")
        File.touch("test/a_tests.ex")
        File.touch("test/ignored_file.exs")
        File.touch("test/ignored_regex.exs")
        File.write!("test/other_file.txt", "this is not a test file")

        output = mix(["test"])

        refute output =~ "the following files do not match"

        # the dummy test ran successfully
        assert output =~ "1 test, 0 failures"
      end)
    end
  end

  describe "--dry-run" do
    test "works with --stale" do
      in_fixture("test_stale", fn ->
        File.write!("test/dry_run_one_test_stale.exs", """
        defmodule DryRunOneTest do
          use ExUnit.Case

          test "new test" do
            assert true
          end
        end
        """)

        File.write!("test/dry_run_two_test_stale.exs", """
        defmodule DryRunTwoTest do
          use ExUnit.Case

          @tag :skip
          test "skipped test" do
            assert true
          end
        end
        """)

        output = mix(["test", "--dry-run", "--stale"])
        assert output =~ "Tests that would be executed:"
        assert output =~ "test/a_test_stale.exs:4"
        assert output =~ "test/b_test_stale.exs:4"
        assert output =~ "test/dry_run_one_test_stale.exs:4"
        refute output =~ "test/dry_run_two_test_stale.exs:5"
        assert output =~ "1 test, 0 failures, 1 skipped"

        # Tests should still be marked as stale
        output = mix(["test", "--dry-run", "--stale"])
        assert output =~ "1 test, 0 failures, 1 skipped"
      end)
    end

    test "works with --failed" do
      in_fixture("test_failed", fn ->
        output = mix(["test"])
        assert output =~ "4 tests, 2 failures"

        output = mix(["test", "--dry-run", "--failed"])
        assert output =~ "Tests that would be executed:"
        assert output =~ "test/only_failing_test_failed.exs:4"
        assert output =~ "test/passing_and_failing_test_failed.exs:5"
        assert output =~ "0 tests, 0 failures"

        # Force the tests to pass, verify dry-run doesn't actually run them
        System.put_env("PASS_FAILING_TESTS", "true")
        output = mix(["test", "--dry-run", "--failed"])
        assert output =~ "0 tests, 0 failures"
      end)
    after
      System.delete_env("PASS_FAILING_TESTS")
    end
  end

  defp receive_until_match(port, expected, acc) do
    receive do
      {^port, {:data, output}} ->
        acc = acc <> output

        if output =~ expected do
          acc
        else
          receive_until_match(port, expected, acc)
        end
    after
      15_000 ->
        raise """
        nothing received from port after 15s.
        Expected: #{inspect(expected)}
        Got: #{inspect(acc)}
        """
    end
  end

  defp set_all_mtimes(time \\ {{2010, 1, 1}, {0, 0, 0}}) do
    Enum.each(Path.wildcard("**", match_dot: true), &File.touch!(&1, time))
  end

  defp assert_stale_run_output(opts \\ [], expected) do
    assert_run_output(["--stale" | opts], expected)
  end

  defp assert_run_output(opts \\ [], expected) do
    assert mix(["test" | opts]) =~ expected
  end
end
