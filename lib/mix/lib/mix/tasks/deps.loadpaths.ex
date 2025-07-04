# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: 2021 The Elixir Team
# SPDX-FileCopyrightText: 2012 Plataformatec

defmodule Mix.Tasks.Deps.Loadpaths do
  use Mix.Task

  import Mix.Dep, only: [format_dep: 1, format_status: 1, check_lock: 1]

  @moduledoc """
  Checks, compiles, and loads dependencies.

  If a dependency has been fetched/updated and not yet compiled,
  it will be automatically compiled. If a dependency is missing
  or is invalid, its status is printed before aborting.

  Although this task does not show up in `mix help`, it is
  part of Mix public API and can be depended on.

  ## Configuration

    * `:listeners` - the list of listener modules. For more details
      see `Mix.Task.Compiler`

  ## Command line options

    * `--no-archives-check` - does not check archives
    * `--no-compile` - does not compile even if files require compilation
    * `--no-deps-check` - does not check or compile deps, only load available ones
    * `--no-elixir-version-check` - does not check Elixir version
    * `--no-listeners` - does not start Mix listeners
    * `--no-optional-deps` - does not compile or load optional deps

  """

  @impl true
  def run(args) do
    # Note that we need to ensure the dependencies are compiled first,
    # before we can start the pub/sub listeners, since those come from
    # the dependencies. Theoretically, between compiling dependencies
    # and starting the listeners, there may be a concurrent compilation
    # of the dependencies, which we would miss, and we would already
    # have modules from our compilation loaded. To avoid this race
    # condition we start the pub/sub beforehand and we accumulate all
    # events until the listeners are started. Alternatively we could
    # use a lock around compilation and sterning the listeners, however
    # the added benefit of the current approach is that we consistently
    # receive events for all dependency compilations. Also, if we ever
    # decide to start the listeners later (e.g. after loadspaths), the
    # accumulation approach still works.
    Mix.PubSub.start()

    if "--no-archives-check" not in args do
      Mix.Task.run("archive.check", args)
    end

    config = Mix.Project.config()

    if "--no-elixir-version-check" not in args do
      check_elixir_version(config)
    end

    all = Mix.Dep.load_and_cache()

    all =
      if "--no-optional-deps" in args do
        for dep <- all, dep.opts[:optional] != true, do: dep
      else
        all
      end

    if "--no-deps-check" not in args do
      deps_check(config, all, "--no-compile" in args)
    end

    Code.prepend_paths(Enum.flat_map(all, &Mix.Dep.load_paths/1), cache: true)

    # For now we only allow listeners defined in dependencies,
    # so we start them right after adding adding deps to the path,
    # as long as we are sure they have been compiled
    if "--listeners" in args or
         ("--no-listeners" not in args and "--no-deps-check" not in args) do
      Mix.PubSub.start_listeners()
    end

    :ok
  end

  defp check_elixir_version(config) do
    if req = config[:elixir] do
      case Version.parse_requirement(req) do
        {:ok, req} ->
          if not Version.match?(System.version(), req) do
            raise Mix.ElixirVersionError,
              target: config[:app] || Mix.Project.get(),
              expected: req,
              actual: System.version()
          end

        :error ->
          Mix.raise("Invalid Elixir version requirement #{req} in mix.exs file")
      end
    end
  end

  defp deps_check(config, all, no_compile?) do
    with {:compile, _to_compile} <- deps_check(all, no_compile?) do
      # We need to compile, we first grab the lock, then, we check
      # again and compile if still applicable
      Mix.Project.with_build_lock(config, fn ->
        all = reload_deps(all)

        with {:compile, to_compile} <- deps_check(all, no_compile?) do
          Mix.Tasks.Deps.Compile.compile(to_compile)

          to_compile
          |> reload_deps()
          |> Enum.filter(&(not Mix.Dep.ok?(&1)))
          |> show_not_ok!()
        end
      end)
    end
  end

  defp deps_check(all, no_compile?) do
    all = Enum.map(all, &check_lock/1)
    {not_ok, to_compile} = partition(all, [], [])

    cond do
      not_ok != [] ->
        show_not_ok!(not_ok)

      to_compile == [] or no_compile? ->
        :ok

      true ->
        {:compile, to_compile}
    end
  end

  defp partition([dep | deps], not_ok, compile) do
    cond do
      Mix.Dep.compilable?(dep) or (Mix.Dep.ok?(dep) and local?(dep)) ->
        partition(deps, not_ok, [dep | compile])

      Mix.Dep.ok?(dep) ->
        partition(deps, not_ok, compile)

      true ->
        partition(deps, [dep | not_ok], compile)
    end
  end

  defp partition([], not_ok, compile) do
    {Enum.reverse(not_ok), Enum.reverse(compile)}
  end

  defp reload_deps(deps) do
    deps
    |> Enum.map(& &1.app)
    |> Mix.Dep.filter_by_name(Mix.Dep.load_and_cache())
  end

  # Every local dependency (i.e. that are not fetchable)
  # are automatically recompiled if they are ok.
  defp local?(dep) do
    not dep.scm.fetchable?()
  end

  defp show_not_ok!([]) do
    :ok
  end

  defp show_not_ok!(deps) do
    shell = Mix.shell()
    shell.error("Unchecked dependencies for environment #{Mix.env()}:")

    Enum.each(deps, fn dep ->
      shell.error("* #{format_dep(dep)}")
      shell.error("  #{format_status(dep)}")
    end)

    Mix.raise("Can't continue due to errors on dependencies")
  end
end
