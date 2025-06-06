# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: 2021 The Elixir Team
# SPDX-FileCopyrightText: 2012 Plataformatec

Code.require_file("test_helper.exs", __DIR__)

defmodule ExceptionTest do
  use ExUnit.Case, async: true

  defp capture_err(fun) do
    ExUnit.CaptureIO.capture_io(:stderr, fun)
  end

  doctest Exception

  doctest RuntimeError
  doctest SystemLimitError
  doctest MismatchedDelimiterError
  doctest SyntaxError
  doctest TokenMissingError
  doctest BadBooleanError
  doctest UndefinedFunctionError
  doctest FunctionClauseError
  doctest Protocol.UndefinedError
  doctest UnicodeConversionError
  doctest Enum.OutOfBoundsError
  doctest Enum.EmptyError
  doctest File.Error
  doctest File.CopyError
  doctest File.RenameError
  doctest File.LinkError
  doctest ErlangError

  test "message/1" do
    defmodule BadException do
      def message(exception) do
        if exception.raise do
          raise "oops"
        end
      end
    end

    assert "got RuntimeError with message \"oops\" while retrieving Exception.message/1 for %{" <>
             inspected =
             Exception.message(%{__struct__: BadException, __exception__: true, raise: true})

    assert inspected =~ "raise: true"
    assert inspected =~ "__exception__: true"
    assert inspected =~ "__struct__: ExceptionTest.BadException"

    assert "got nil while retrieving Exception.message/1 for %{" <> inspected =
             Exception.message(%{__struct__: BadException, __exception__: true, raise: false})

    assert inspected =~ "raise: false"
    assert inspected =~ "__exception__: true"
    assert inspected =~ "__struct__: ExceptionTest.BadException"
  end

  test "normalize/2" do
    assert Exception.normalize(:throw, :badarg, []) == :badarg
    assert Exception.normalize(:exit, :badarg, []) == :badarg
    assert Exception.normalize({:EXIT, self()}, :badarg, []) == :badarg
    assert Exception.normalize(:error, :badarg, []).__struct__ == ArgumentError
    assert Exception.normalize(:error, %ArgumentError{}, []).__struct__ == ArgumentError

    assert %ErlangError{original: :no_translation, reason: ": foo"} =
             Exception.normalize(:error, :no_translation, [
               {:io, :put_chars, [self(), <<222>>],
                [error_info: %{module: __MODULE__, function: :dummy_error_extras}]}
             ])

    assert %ErlangError{original: {:failed_load_cacerts, :enoent}, reason: ": this is chardata"} =
             Exception.normalize(:error, {:failed_load_cacerts, :enoent}, [
               {:pubkey_os_cacerts, :get, 0,
                [error_info: %{module: __MODULE__, function: :dummy_error_chardata}]}
             ])
  end

  test "format/2 without stacktrace" do
    stacktrace =
      try do
        throw(:stack)
      catch
        :stack -> __STACKTRACE__
      end

    assert Exception.format(:error, :badarg, stacktrace) ==
             "** (ArgumentError) argument error\n" <> Exception.format_stacktrace(stacktrace)
  end

  test "format/2 with empty stacktrace" do
    assert Exception.format(:error, :badarg, []) == "** (ArgumentError) argument error"
  end

  test "format/2 with EXIT (has no stacktrace)" do
    assert Exception.format({:EXIT, self()}, :badarg, []) ==
             "** (EXIT from #{inspect(self())}) :badarg"
  end

  test "format_banner/2" do
    assert Exception.format_banner(:error, :badarg) == "** (ArgumentError) argument error"
    assert Exception.format_banner(:throw, :badarg) == "** (throw) :badarg"
    assert Exception.format_banner(:exit, :badarg) == "** (exit) :badarg"

    assert Exception.format_banner({:EXIT, self()}, :badarg) ==
             "** (EXIT from #{inspect(self())}) :badarg"
  end

  test "format_stacktrace/1 from file" do
    try do
      Code.eval_string("def foo do end", [], file: "my_file")
    rescue
      ArgumentError ->
        assert Exception.format_stacktrace(__STACKTRACE__) =~ "my_file:1: (file)"
    else
      _ -> flunk("expected failure")
    end
  end

  test "format_stacktrace/1 from module" do
    try do
      Code.eval_string(
        "defmodule FmtStack do raise ArgumentError, ~s(oops) end",
        [],
        file: "my_file"
      )
    rescue
      ArgumentError ->
        assert Exception.format_stacktrace(__STACKTRACE__) =~ "my_file:1: (module)"
    else
      _ -> flunk("expected failure")
    end
  end

  test "format_stacktrace_entry/1 with no file or line" do
    assert Exception.format_stacktrace_entry({Foo, :bar, [1, 2, 3], []}) == "Foo.bar(1, 2, 3)"
    assert Exception.format_stacktrace_entry({Foo, :bar, [], []}) == "Foo.bar()"
    assert Exception.format_stacktrace_entry({Foo, :bar, 1, []}) == "Foo.bar/1"
  end

  test "format_stacktrace_entry/1 with file and line" do
    assert Exception.format_stacktrace_entry({Foo, :bar, [], [file: ~c"file.ex", line: 10]}) ==
             "file.ex:10: Foo.bar()"

    assert Exception.format_stacktrace_entry(
             {Foo, :bar, [1, 2, 3], [file: ~c"file.ex", line: 10]}
           ) ==
             "file.ex:10: Foo.bar(1, 2, 3)"

    assert Exception.format_stacktrace_entry({Foo, :bar, 1, [file: ~c"file.ex", line: 10]}) ==
             "file.ex:10: Foo.bar/1"
  end

  test "format_stacktrace_entry/1 with file no line" do
    assert Exception.format_stacktrace_entry({Foo, :bar, [], [file: ~c"file.ex"]}) ==
             "file.ex: Foo.bar()"

    assert Exception.format_stacktrace_entry({Foo, :bar, [], [file: ~c"file.ex", line: 0]}) ==
             "file.ex: Foo.bar()"

    assert Exception.format_stacktrace_entry({Foo, :bar, [1, 2, 3], [file: ~c"file.ex"]}) ==
             "file.ex: Foo.bar(1, 2, 3)"

    assert Exception.format_stacktrace_entry({Foo, :bar, 1, [file: ~c"file.ex"]}) ==
             "file.ex: Foo.bar/1"
  end

  test "format_stacktrace_entry/1 with application" do
    assert Exception.format_stacktrace_entry({Exception, :bar, [], [file: ~c"file.ex"]}) ==
             "(elixir #{System.version()}) file.ex: Exception.bar()"

    assert Exception.format_stacktrace_entry({Exception, :bar, [], [file: ~c"file.ex", line: 10]}) ==
             "(elixir #{System.version()}) file.ex:10: Exception.bar()"
  end

  test "format_stacktrace_entry/1 with fun" do
    assert Exception.format_stacktrace_entry({fn x -> x end, [1], []}) =~ ~r/#Function<.+>\(1\)/

    assert Exception.format_stacktrace_entry({fn x, y -> {x, y} end, 2, []}) =~
             ~r"#Function<.+>/2"
  end

  test "format_mfa/3" do
    # Let's create this atom so that String.to_existing_atom/1 inside
    # format_mfa/3 doesn't raise.
    _ = :"some function"

    assert Exception.format_mfa(Foo, nil, 1) == "Foo.nil/1"
    assert Exception.format_mfa(Foo, :bar, 1) == "Foo.bar/1"
    assert Exception.format_mfa(Foo, :bar, []) == "Foo.bar()"
    assert Exception.format_mfa(nil, :bar, []) == "nil.bar()"
    assert Exception.format_mfa(:foo, :bar, [1, 2]) == ":foo.bar(1, 2)"
    assert Exception.format_mfa(Foo, :b@r, 1) == "Foo.\"b@r\"/1"
    assert Exception.format_mfa(Foo, :"bar baz", 1) == "Foo.\"bar baz\"/1"
    assert Exception.format_mfa(Foo, :"-func/2-fun-0-", 4) == "anonymous fn/4 in Foo.func/2"

    assert Exception.format_mfa(Foo, :"-some function/2-fun-0-", 4) ==
             "anonymous fn/4 in Foo.\"some function\"/2"

    assert Exception.format_mfa(Foo, :"42", 1) == "Foo.\"42\"/1"
    assert Exception.format_mfa(Foo, :Bar, [1, 2]) == "Foo.\"Bar\"(1, 2)"
    assert Exception.format_mfa(Foo, :%{}, [1, 2]) == "Foo.\"%{}\"(1, 2)"
    assert Exception.format_mfa(Foo, :..., 1) == "Foo.\"...\"/1"
  end

  test "format_mfa/3 with Unicode" do
    assert Exception.format_mfa(Foo, :olá, [1, 2]) == "Foo.olá(1, 2)"
    assert Exception.format_mfa(Foo, :Olá, [1, 2]) == "Foo.\"Olá\"(1, 2)"
    assert Exception.format_mfa(Foo, :Ólá, [1, 2]) == "Foo.\"Ólá\"(1, 2)"
    assert Exception.format_mfa(Foo, :こんにちは世界, [1, 2]) == "Foo.こんにちは世界(1, 2)"

    nfd = :unicode.characters_to_nfd_binary("olá")
    assert Exception.format_mfa(Foo, String.to_atom(nfd), [1, 2]) == "Foo.\"#{nfd}\"(1, 2)"
  end

  test "format_fa/2" do
    assert Exception.format_fa(fn -> nil end, 1) =~
             ~r"#Function<\d+\.\d+/0 in ExceptionTest\.\"test format_fa/2\"/1>/1"
  end

  describe "format_exit/1" do
    test "with atom/tuples" do
      assert Exception.format_exit(:bye) == ":bye"
      assert Exception.format_exit(:noconnection) == "no connection"
      assert Exception.format_exit({:nodedown, :node@host}) == "no connection to node@host"
      assert Exception.format_exit(:timeout) == "time out"
      assert Exception.format_exit(:noproc) |> String.starts_with?("no process:")
      assert Exception.format_exit(:killed) == "killed"
      assert Exception.format_exit(:normal) == "normal"
      assert Exception.format_exit(:shutdown) == "shutdown"
      assert Exception.format_exit(:calling_self) == "process attempted to call itself"
      assert Exception.format_exit({:shutdown, :bye}) == "shutdown: :bye"

      assert Exception.format_exit({:badarg, [{:not_a_real_module, :function, 0, []}]}) ==
               "an exception was raised:\n    ** (ArgumentError) argument error\n        :not_a_real_module.function/0"

      assert Exception.format_exit({:bad_call, :request}) == "bad call: :request"
      assert Exception.format_exit({:bad_cast, :request}) == "bad cast: :request"

      assert Exception.format_exit({:start_spec, :unexpected}) ==
               "bad child specification, got: :unexpected"

      assert Exception.format_exit({:supervisor_data, :unexpected}) ==
               "bad supervisor configuration, got: :unexpected"
    end

    defmodule Sup do
      def start_link(fun), do: :supervisor.start_link(__MODULE__, fun)

      def init(fun), do: fun.()
    end

    test "with supervisor errors" do
      Process.flag(:trap_exit, true)

      {:error, reason} = __MODULE__.Sup.start_link(fn -> :foo end)

      assert Exception.format_exit(reason) ==
               "#{inspect(__MODULE__.Sup)}.init/1 returned a bad value: :foo"

      return = {:ok, {:foo, []}}
      {:error, reason} = __MODULE__.Sup.start_link(fn -> return end)
      assert Exception.format_exit(reason) == "bad supervisor configuration, invalid type: :foo"

      return = {:ok, {{:foo, 1, 1}, []}}
      {:error, reason} = __MODULE__.Sup.start_link(fn -> return end)

      assert Exception.format_exit(reason) ==
               "bad supervisor configuration, invalid strategy: :foo"

      return = {:ok, {{:one_for_one, :foo, 1}, []}}
      {:error, reason} = __MODULE__.Sup.start_link(fn -> return end)

      assert Exception.format_exit(reason) ==
               "bad supervisor configuration, invalid max_restarts (intensity): :foo"

      return = {:ok, {{:one_for_one, 1, :foo}, []}}
      {:error, reason} = __MODULE__.Sup.start_link(fn -> return end)

      assert Exception.format_exit(reason) ==
               "bad supervisor configuration, invalid max_seconds (period): :foo"

      return = {:ok, {{:simple_one_for_one, 1, 1}, :foo}}
      {:error, reason} = __MODULE__.Sup.start_link(fn -> return end)
      assert Exception.format_exit(reason) == "bad child specification, invalid children: :foo"

      return = {:ok, {{:one_for_one, 1, 1}, [:foo]}}
      {:error, reason} = __MODULE__.Sup.start_link(fn -> return end)

      assert Exception.format_exit(reason) ==
               "bad child specification, invalid child specification: :foo"

      return = {:ok, {{:one_for_one, 1, 1}, [{:child, :foo, :temporary, 1, :worker, []}]}}
      {:error, reason} = __MODULE__.Sup.start_link(fn -> return end)
      assert Exception.format_exit(reason) == "bad child specification, invalid mfa: :foo"

      return = {:ok, {{:one_for_one, 1, 1}, [{:child, {:m, :f, []}, :foo, 1, :worker, []}]}}
      {:error, reason} = __MODULE__.Sup.start_link(fn -> return end)

      assert Exception.format_exit(reason) =~
               "bad child specification, invalid restart type: :foo"

      return = {
        :ok,
        {{:one_for_one, 1, 1}, [{:child, {:m, :f, []}, :temporary, :foo, :worker, []}]}
      }

      {:error, reason} = __MODULE__.Sup.start_link(fn -> return end)
      assert Exception.format_exit(reason) =~ "bad child specification, invalid shutdown: :foo"

      return = {:ok, {{:one_for_one, 1, 1}, [{:child, {:m, :f, []}, :temporary, 1, :foo, []}]}}
      {:error, reason} = __MODULE__.Sup.start_link(fn -> return end)
      assert Exception.format_exit(reason) =~ "bad child specification, invalid child type: :foo"

      return =
        {:ok, {{:one_for_one, 1, 1}, [{:child, {:m, :f, []}, :temporary, 1, :worker, :foo}]}}

      {:error, reason} = __MODULE__.Sup.start_link(fn -> return end)
      assert Exception.format_exit(reason) =~ "bad child specification, invalid modules: :foo"

      return = {
        :ok,
        {{:one_for_one, 1, 1}, [{:child, {:m, :f, []}, :temporary, 1, :worker, [{:foo}]}]}
      }

      {:error, reason} = __MODULE__.Sup.start_link(fn -> return end)
      assert Exception.format_exit(reason) =~ "bad child specification, invalid module: {:foo}"

      return = {
        :ok,
        {
          {:one_for_one, 1, 1},
          [
            {:child, {:m, :f, []}, :permanent, 1, :worker, []},
            {:child, {:m, :f, []}, :permanent, 1, :worker, []}
          ]
        }
      }

      {:error, reason} = __MODULE__.Sup.start_link(fn -> return end)

      assert Exception.format_exit(reason) =~
               "bad child specification, more than one child specification has the id: :child"

      return = {
        :ok,
        {{:one_for_one, 1, 1}, [{:child, {Kernel, :exit, [:foo]}, :temporary, 1, :worker, []}]}
      }

      {:error, reason} = __MODULE__.Sup.start_link(fn -> return end)

      assert Exception.format_exit(reason) ==
               "shutdown: failed to start child: :child\n    ** (EXIT) :foo"

      return = {
        :ok,
        {
          {:one_for_one, 1, 1},
          [{:child, {Kernel, :apply, [fn -> {:error, :foo} end, []]}, :temporary, 1, :worker, []}]
        }
      }

      {:error, reason} = __MODULE__.Sup.start_link(fn -> return end)

      assert Exception.format_exit(reason) ==
               "shutdown: failed to start child: :child\n    ** (EXIT) :foo"
    end

    test "with call" do
      reason =
        try do
          :gen_server.call(:does_not_exist, :hello)
        catch
          :exit, reason -> reason
        end

      expected_to_start_with =
        "exited in: :gen_server.call(:does_not_exist, :hello)\n    ** (EXIT) no process:"

      assert Exception.format_exit(reason) |> String.starts_with?(expected_to_start_with)
    end

    test "with nested calls" do
      Process.flag(:trap_exit, true)
      # Fake reason to prevent error_logger printing to stdout
      exit_fun = fn -> receive do: (_ -> exit(:normal)) end

      outer_pid =
        spawn_link(fn ->
          Process.flag(:trap_exit, true)

          receive do
            _ ->
              :gen_event.call(spawn_link(exit_fun), :handler, :hello)
          end
        end)

      reason =
        try do
          :gen_server.call(outer_pid, :hi)
        catch
          :exit, reason -> reason
        end

      formatted = Exception.format_exit(reason)
      assert formatted =~ ~r"exited in: :gen_server\.call\(#PID<\d+\.\d+\.\d+>, :hi\)\n"

      assert formatted =~
               ~r"\s{4}\*\* \(EXIT\) exited in: :gen_event\.call\(#PID<\d+\.\d+\.\d+>, :handler, :hello\)\n"

      assert formatted =~ ~r"\s{8}\*\* \(EXIT\) normal"
    end

    test "format_exit/1 with nested calls and exception" do
      Process.flag(:trap_exit, true)
      # Fake reason to prevent error_logger printing to stdout
      exit_reason = {%ArgumentError{}, [{:not_a_real_module, :function, 0, []}]}
      exit_fun = fn -> receive do: (_ -> exit(exit_reason)) end

      outer_pid =
        spawn_link(fn ->
          Process.flag(:trap_exit, true)
          :gen_event.call(spawn_link(exit_fun), :handler, :hello)
        end)

      reason =
        try do
          :gen_server.call(outer_pid, :hi)
        catch
          :exit, reason -> reason
        end

      formatted = Exception.format_exit(reason)
      assert formatted =~ ~r"exited in: :gen_server\.call\(#PID<\d+\.\d+\.\d+>, :hi\)\n"

      assert formatted =~
               ~r"\s{4}\*\* \(EXIT\) exited in: :gen_event\.call\(#PID<\d+\.\d+\.\d+>, :handler, :hello\)\n"

      assert formatted =~ ~r"\s{8}\*\* \(EXIT\) an exception was raised:\n"
      assert formatted =~ ~r"\s{12}\*\* \(ArgumentError\) argument error\n"
      assert formatted =~ ~r"\s{16}:not_a_real_module\.function/0"
    end
  end

  describe "blaming" do
    test "does not annotate throws/exits" do
      stack = [{Keyword, :pop, [%{}, :key, nil], [line: 13]}]
      assert Exception.blame(:throw, :function_clause, stack) == {:function_clause, stack}
      assert Exception.blame(:exit, :function_clause, stack) == {:function_clause, stack}
    end

    test "handles operators precedence" do
      import PathHelpers

      write_beam(
        defmodule OperatorPrecedence do
          def test!(x, y) when x in [1, 2, 3] and y >= 4, do: :ok
        end
      )

      :code.purge(OperatorPrecedence)
      :code.delete(OperatorPrecedence)

      assert blame_message(OperatorPrecedence, & &1.test!(1, 2)) =~ """
             no function clause matching in ExceptionTest.OperatorPrecedence.test!/2

             The following arguments were given to ExceptionTest.OperatorPrecedence.test!/2:

                 # 1
                 1

                 # 2
                 2

             Attempted function clauses (showing 1 out of 1):

                 def test!(x, y) when (x === 1 or -x === 2- or -x === 3-) and -y >= 4-
             """
    end

    test "reverts is_struct macro on guards for blaming" do
      import PathHelpers

      write_beam(
        defmodule Req do
          def get!(url)
              when is_binary(url) or (is_struct(url) and is_struct(url, URI) and false) do
            url
          end

          def get!(url, url_module)
              when is_binary(url) or (is_struct(url) and is_struct(url, url_module) and false) do
            url
          end

          def sub_get!(url) when is_struct(url.sub, URI), do: url.sub
        end
      )

      :code.purge(Req)
      :code.delete(Req)

      assert blame_message(Req, & &1.get!(url: "https://elixir-lang.org")) =~ """
             no function clause matching in ExceptionTest.Req.get!/1

             The following arguments were given to ExceptionTest.Req.get!/1:

                 # 1
                 [url: "https://elixir-lang.org"]

             Attempted function clauses (showing 1 out of 1):

                 def get!(url) when -is_binary(url)- or -is_struct(url)- and -is_struct(url, URI)- and -false-
             """

      elixir_uri = %URI{} = URI.parse("https://elixir-lang.org")

      assert blame_message(Req, & &1.get!(elixir_uri, URI)) =~ """
             no function clause matching in ExceptionTest.Req.get!/2

             The following arguments were given to ExceptionTest.Req.get!/2:

                 # 1
                 %URI{scheme: \"https\", authority: \"elixir-lang.org\", userinfo: nil, host: \"elixir-lang.org\", port: 443, path: nil, query: nil, fragment: nil}

                 # 2
                 URI

             Attempted function clauses (showing 1 out of 1):

                 def get!(url, url_module) when -is_binary(url)- or is_struct(url) and is_struct(url, url_module) and -false-
             """

      assert blame_message(Req, & &1.get!(elixir_uri)) =~ """
             no function clause matching in ExceptionTest.Req.get!/1

             The following arguments were given to ExceptionTest.Req.get!/1:

                 # 1
                 %URI{scheme: \"https\", authority: \"elixir-lang.org\", userinfo: nil, host: \"elixir-lang.org\", port: 443, path: nil, query: nil, fragment: nil}

             Attempted function clauses (showing 1 out of 1):

                 def get!(url) when -is_binary(url)- or is_struct(url) and is_struct(url, URI) and -false-
             """

      assert blame_message(Req, & &1.sub_get!(%{})) =~ """
             no function clause matching in ExceptionTest.Req.sub_get!/1

             The following arguments were given to ExceptionTest.Req.sub_get!/1:

                 # 1
                 %{}

             Attempted function clauses (showing 1 out of 1):

                 def sub_get!(url) when -is_struct(url.sub, URI)-
             """
    end

    test "annotates badarg on apply" do
      assert blame_message([], & &1.foo()) ==
               "you attempted to apply a function named :foo on []. If you are using Kernel.apply/3, make sure " <>
                 "the module is an atom. If you are using the dot syntax, such as " <>
                 "module.function(), make sure the left-hand side of the dot is an atom representing a module"

      assert blame_message([], &apply(&1, :foo, [])) ==
               "you attempted to apply a function named :foo on []. If you are using Kernel.apply/3, make sure " <>
                 "the module is an atom. If you are using the dot syntax, such as " <>
                 "module.function(), make sure the left-hand side of the dot is an atom representing a module"

      assert blame_message([], &apply(&1, :foo, [1, 2])) ==
               "you attempted to apply a function on []. Modules (the first argument of apply) must always be an atom"
    end

    test "annotates function clause errors" do
      import PathHelpers

      write_beam(
        defmodule ExampleModule do
          def fun(arg1, arg2)
          def fun(:one, :one), do: :ok
          def fun(:two, :two), do: :ok
        end
      )

      message = blame_message(ExceptionTest.ExampleModule, & &1.fun(:three, :four))

      assert message =~ """
             no function clause matching in ExceptionTest.ExampleModule.fun/2

             The following arguments were given to ExceptionTest.ExampleModule.fun/2:

                 # 1
                 :three

                 # 2
                 :four

             Attempted function clauses (showing 2 out of 2):

                 def fun(-:one-, -:one-)
                 def fun(-:two-, -:two-)
             """
    end

    test "annotates undefined function error with suggestions" do
      assert blame_message(Enum, & &1.map(:ok)) == """
             function Enum.map/1 is undefined or private. Did you mean:

                   * map/2
             """

      assert blame_message(Enum, & &1.man(:ok)) == """
             function Enum.man/1 is undefined or private. Did you mean:

                   * map/2
                   * max/1
                   * max/2
                   * max/3
                   * min/1
             """

      message = blame_message(:erlang, & &1.gt_cookie())
      assert message =~ "function :erlang.gt_cookie/0 is undefined or private. Did you mean:"
      assert message =~ "* get_cookie/0"
      assert message =~ "* set_cookie/2"
    end

    test "annotates undefined function error with module suggestions" do
      import PathHelpers

      modules = [
        Namespace.A.One,
        Namespace.A.Two,
        Namespace.A.Three,
        Namespace.B.One,
        Namespace.B.Two,
        Namespace.B.Three
      ]

      for module <- modules do
        write_beam(
          defmodule module do
            def foo, do: :bar
          end
        )
      end

      assert blame_message(ENUM, & &1.map(&1, 1)) == """
             function ENUM.map/2 is undefined (module ENUM is not available). Did you mean:

                   * Enum.map/2
             """

      assert blame_message(ENUM, & &1.not_a_function(&1, 1)) ==
               "function ENUM.not_a_function/2 is undefined (module ENUM is not available). " <>
                 "Make sure the module name is correct and has been specified in full (or that an alias has been defined)"

      assert blame_message(One, & &1.foo()) == """
             function One.foo/0 is undefined (module One is not available). Did you mean:

                   * Namespace.A.One.foo/0
                   * Namespace.B.One.foo/0
             """

      for module <- modules do
        :code.purge(module)
        :code.delete(module)
      end
    end

    test "annotates undefined function clause error with macro hints" do
      assert blame_message(Integer, & &1.is_odd(1)) ==
               "function Integer.is_odd/1 is undefined or private. However, there is " <>
                 "a macro with the same name and arity. Be sure to require Integer if " <>
                 "you intend to invoke this macro"
    end

    test "annotates undefined function clause error with callback hints" do
      capture_err(fn ->
        Code.eval_string("""
          defmodule Behaviour do
            @callback callback() :: :ok
          end

          defmodule Implementation do
            @behaviour Behaviour
          end
        """)
      end)

      assert blame_message(Implementation, & &1.callback()) ==
               "function Implementation.callback/0 is undefined or private" <>
                 ", but the behaviour Behaviour expects it to be present"
    end

    test "does not annotate undefined function clause error with callback hints when callback is optional" do
      defmodule BehaviourWithOptional do
        @callback callback() :: :ok
        @callback optional() :: :ok
        @optional_callbacks callback: 0, optional: 0
      end

      defmodule ImplementationWithOptional do
        @behaviour BehaviourWithOptional
        def callback(), do: :ok
      end

      assert blame_message(ImplementationWithOptional, & &1.optional()) ==
               "function ExceptionTest.ImplementationWithOptional.optional/0 is undefined or private"
    end

    test "annotates undefined function clause error with otp obsolete hints" do
      assert blame_message(:erlang, & &1.hash(1, 2)) ==
               "function :erlang.hash/2 is undefined or private, use erlang:phash2/2 instead"
    end

    test "annotates undefined function clause error with nil hints" do
      assert blame_message(nil, & &1.foo()) ==
               "function nil.foo/0 is undefined. If you are using the dot syntax, " <>
                 "such as module.function(), make sure the left-hand side of " <>
                 "the dot is a module atom"

      assert blame_message("nil.foo()", &Code.eval_string/1) ==
               "function nil.foo/0 is undefined. If you are using the dot syntax, " <>
                 "such as module.function(), make sure the left-hand side of " <>
                 "the dot is a module atom"
    end

    test "annotates key error with suggestions if keys are atoms" do
      message = blame_message(%{first: nil, second: nil}, fn map -> map.firts end)

      assert message == """
             key :firts not found in:

                 %{first: nil, second: nil}

             Did you mean:

                   * :first
             """

      message = blame_message(%{"first" => nil, "second" => nil}, fn map -> map.firts end)

      assert message == """
             key :firts not found in:

                 %{"first" => nil, "second" => nil}\
             """

      message =
        blame_message(%{"first" => nil, "second" => nil}, fn map -> Map.fetch!(map, "firts") end)

      assert message ==
               """
               key "firts" not found in:

                   %{"first" => nil, "second" => nil}\
               """

      message =
        blame_message(
          [
            created_at: nil,
            updated_at: nil,
            deleted_at: nil,
            started_at: nil,
            finished_at: nil
          ],
          fn kwlist ->
            Keyword.fetch!(kwlist, :inserted_at)
          end
        )

      assert message == """
             key :inserted_at not found in:

                 [
                   created_at: nil,
                   updated_at: nil,
                   deleted_at: nil,
                   started_at: nil,
                   finished_at: nil
                 ]

             Did you mean:

                   * :created_at
                   * :finished_at
                   * :started_at
             """
    end

    test "annotates key error with suggestions for structs" do
      message = blame_message(%URI{}, fn map -> map.schema end)
      assert message =~ "key :schema not found in:\n\n    %URI{"
      assert message =~ "Did you mean:"
      assert message =~ "* :scheme"
    end

    test "annotates +/1 arithmetic errors" do
      assert blame_message(:foo, &(+&1)) == "bad argument in arithmetic expression: +(:foo)"
    end

    test "annotates -/1 arithmetic errors" do
      assert blame_message(:foo, &(-&1)) == "bad argument in arithmetic expression: -(:foo)"
    end

    test "annotates div arithmetic errors" do
      assert blame_message(0, &div(10, &1)) ==
               "bad argument in arithmetic expression: div(10, 0)"
    end

    test "annotates rem arithmetic errors" do
      assert blame_message(0, &rem(10, &1)) ==
               "bad argument in arithmetic expression: rem(10, 0)"
    end

    test "annotates band arithmetic errors" do
      import Bitwise

      assert blame_message(:foo, &band(&1, 10)) ==
               "bad argument in arithmetic expression: Bitwise.band(:foo, 10)"

      assert blame_message(:foo, &(&1 &&& 10)) ==
               "bad argument in arithmetic expression: Bitwise.band(:foo, 10)"
    end

    test "annotates bor arithmetic errors" do
      import Bitwise

      assert blame_message(:foo, &bor(&1, 10)) ==
               "bad argument in arithmetic expression: Bitwise.bor(:foo, 10)"

      assert blame_message(:foo, &(&1 ||| 10)) ==
               "bad argument in arithmetic expression: Bitwise.bor(:foo, 10)"
    end

    test "annotates bxor arithmetic errors" do
      import Bitwise

      assert blame_message(:foo, &bxor(&1, 10)) ==
               "bad argument in arithmetic expression: Bitwise.bxor(:foo, 10)"
    end

    test "annotates bsl arithmetic errors" do
      import Bitwise

      assert blame_message(:foo, &bsl(10, &1)) ==
               "bad argument in arithmetic expression: Bitwise.bsl(10, :foo)"

      assert blame_message(:foo, &(10 <<< &1)) ==
               "bad argument in arithmetic expression: Bitwise.bsl(10, :foo)"
    end

    test "annotates bsr arithmetic errors" do
      import Bitwise

      assert blame_message(:foo, &bsr(10, &1)) ==
               "bad argument in arithmetic expression: Bitwise.bsr(10, :foo)"

      assert blame_message(:foo, &(10 >>> &1)) ==
               "bad argument in arithmetic expression: Bitwise.bsr(10, :foo)"
    end

    test "annotates bnot arithmetic errors" do
      import Bitwise

      assert blame_message(:foo, &bnot(&1)) ==
               "bad argument in arithmetic expression: Bitwise.bnot(:foo)"
    end

    defp blame_message(arg, fun) do
      try do
        fun.(arg)
      rescue
        e ->
          Exception.blame(:error, e, __STACKTRACE__) |> elem(0) |> Exception.message()
      end
    end
  end

  describe "blaming unit tests" do
    test "annotates clauses errors" do
      import PathHelpers

      write_beam(
        defmodule BlameModule do
          def fun(arg), do: arg
        end
      )

      args = [nil]

      {exception, stack} =
        Exception.blame(:error, :function_clause, [{BlameModule, :fun, args, [line: 13]}])

      assert %FunctionClauseError{kind: :def, args: ^args, clauses: [_]} = exception
      assert stack == [{BlameModule, :fun, 1, [line: 13]}]
    end

    @tag :require_ast
    test "annotates args and clauses from mfa" do
      import PathHelpers

      write_beam(
        defmodule Blaming do
          def with_elem(x, y) when elem(x, 1) == 0 and elem(x, y) == 1 do
            {x, y}
          end

          def fetch(%module{} = container, key), do: {module, container, key}
          def fetch(map, key) when is_map(map), do: {map, key}
          def fetch(list, key) when is_list(list) and is_atom(key), do: {list, key}
          def fetch(nil, _key), do: nil

          require Integer
          def even_and_odd(foo, bar) when Integer.is_even(foo) and Integer.is_odd(bar), do: :ok
        end
      )

      :code.purge(Blaming)
      :code.delete(Blaming)

      {:ok, :def, clauses} = Exception.blame_mfa(Blaming, :with_elem, [1, 2])

      assert annotated_clauses_to_string(clauses) == [
               "{[+x+, +y+], [-elem(x, 1) == 0- and -elem(x, y) == 1-]}"
             ]

      {:ok, :def, clauses} = Exception.blame_mfa(Blaming, :fetch, [self(), "oops"])

      assert annotated_clauses_to_string(clauses) == [
               "{[-%module{} = container-, +key+], []}",
               "{[+map+, +key+], [-is_map(map)-]}",
               "{[+list+, +key+], [-is_list(list)- and -is_atom(key)-]}",
               "{[-nil-, +_key+], []}"
             ]

      {:ok, :def, clauses} = Exception.blame_mfa(Blaming, :even_and_odd, [1, 1])

      assert annotated_clauses_to_string(clauses) == [
               "{[+foo+, +bar+], [+is_integer(foo)+ and -Bitwise.band(foo, 1) == 0- and +is_integer(bar)+ and +Bitwise.band(bar, 1) == 1+]}"
             ]

      {:ok, :defmacro, clauses} = Exception.blame_mfa(Kernel, :!, [true])

      assert annotated_clauses_to_string(clauses) == [
               "{[-{:!, _, [value]}-], []}",
               "{[+value+], []}"
             ]
    end

    defp annotated_clauses_to_string(clauses) do
      Enum.map(clauses, fn {args, clauses} ->
        args = Enum.map_join(args, ", ", &arg_to_string/1)
        clauses = Enum.map_join(clauses, ", ", &clause_to_string/1)
        "{[#{args}], [#{clauses}]}"
      end)
    end

    defp arg_to_string(%{match?: true, node: node}), do: "+" <> Macro.to_string(node) <> "+"
    defp arg_to_string(%{match?: false, node: node}), do: "-" <> Macro.to_string(node) <> "-"

    defp clause_to_string({op, _, [left, right]}),
      do: clause_to_string(left) <> " #{op} " <> clause_to_string(right)

    defp clause_to_string(other),
      do: arg_to_string(other)
  end

  describe "exception messages" do
    import Exception, only: [message: 1]

    test "RuntimeError" do
      assert %RuntimeError{} |> message() == "runtime error"
      assert %RuntimeError{message: "unexpected roquefort"} |> message() == "unexpected roquefort"
    end

    test "ArithmeticError" do
      assert %ArithmeticError{} |> message() == "bad argument in arithmetic expression"

      assert %ArithmeticError{message: "unexpected camembert"}
             |> message() == "unexpected camembert"
    end

    test "ArgumentError" do
      assert %ArgumentError{} |> message() == "argument error"
      assert %ArgumentError{message: "unexpected comté"} |> message() == "unexpected comté"
    end

    test "KeyError" do
      assert %KeyError{} |> message() == "key nil not found"
      assert %KeyError{message: "key missed"} |> message() == "key missed"
    end

    test "Enum.OutOfBoundsError" do
      assert %Enum.OutOfBoundsError{} |> message() == "out of bounds error"

      assert %Enum.OutOfBoundsError{message: "the brie is not on the table"}
             |> message() == "the brie is not on the table"
    end

    test "Enum.EmptyError" do
      assert %Enum.EmptyError{} |> message() == "empty error"

      assert %Enum.EmptyError{message: "there is no saint-nectaire left!"}
             |> message() == "there is no saint-nectaire left!"
    end

    test "UndefinedFunctionError" do
      assert %UndefinedFunctionError{} |> message() == "undefined function"

      assert %UndefinedFunctionError{module: Kernel, function: :bar, arity: 1}
             |> message() == "function Kernel.bar/1 is undefined or private"

      assert %UndefinedFunctionError{module: Foo, function: :bar, arity: 1}
             |> message() ==
               "function Foo.bar/1 is undefined (module Foo is not available). " <>
                 "Make sure the module name is correct and has been specified in full (or that an alias has been defined)"

      assert %UndefinedFunctionError{module: nil, function: :bar, arity: 3}
             |> message() == "function nil.bar/3 is undefined"

      assert %UndefinedFunctionError{module: nil, function: :bar, arity: 0}
             |> message() == "function nil.bar/0 is undefined"
    end

    test "FunctionClauseError" do
      assert %FunctionClauseError{} |> message() == "no function clause matches"

      assert %FunctionClauseError{module: Foo, function: :bar, arity: 1}
             |> message() == "no function clause matching in Foo.bar/1"
    end

    test "ErlangError" do
      assert %ErlangError{original: :sample} |> message() == "Erlang error: :sample"
    end

    test "MissingApplicationsError" do
      assert %MissingApplicationsError{
               apps: [{:logger, "~> 1.18"}, {:ex_unit, Version.parse_requirement!(">= 0.0.0")}],
               description: "applications are required"
             }
             |> message() == """
             applications are required

             To address this, include these applications as your dependencies:

               {:logger, "~> 1.18"}
               {:ex_unit, ">= 0.0.0"}\
             """
    end
  end

  describe "error_info" do
    test "badarg on erlang" do
      assert message(:erlang, & &1.element("foo", "bar")) == """
             errors were found at the given arguments:

               * 1st argument: not an integer
               * 2nd argument: not a tuple
             """
    end

    test "badarg on ets" do
      ets = :ets.new(:foo, [])
      :ets.delete(ets)

      assert message(:ets, & &1.insert(ets, 1)) == """
             errors were found at the given arguments:

               * 1st argument: the table identifier does not refer to an existing ETS table
               * 2nd argument: not a tuple
             """
    end

    test "system_limit on counters" do
      assert message(:counters, & &1.new(123_456_789_123_456_789_123_456_789, [])) == """
             a system limit has been reached due to errors at the given arguments:

               * 1st argument: counters array size reached a system limit
             """
    end
  end

  describe "binary constructor error info" do
    defp concat(a, b), do: a <> b

    test "on binary concatenation" do
      assert message(123, &concat(&1, "bar")) ==
               "construction of binary failed: segment 1 of type 'binary': expected a binary but got: 123"

      assert message(~D[0001-02-03], &concat(&1, "bar")) ==
               "construction of binary failed: segment 1 of type 'binary': expected a binary but got: ~D[0001-02-03]"
    end
  end

  defp message(arg, fun) do
    try do
      fun.(arg)
    rescue
      e -> Exception.message(e)
    end
  end

  def dummy_error_extras(_exception, _stacktrace), do: %{general: "foo"}

  def dummy_error_chardata(_exception, _stacktrace) do
    %{general: ~c"this is " ++ [~c"chardata"], reason: ~c"this " ++ [~c"too"]}
  end
end
