%% SPDX-License-Identifier: Apache-2.0
%% SPDX-FileCopyrightText: 2021 The Elixir Team
%% SPDX-FileCopyrightText: 2012 Plataformatec

-module(elixir_rewrite).
-compile({inline, [inner_inline/4, inner_rewrite/5]}).
-compile(nowarn_shadow_vars).
-export([erl_to_ex/3, inline/3, rewrite/5, match/6, guard/6, format_error/1]).
-include("elixir.hrl").

%% Convenience variables

-define(atom, 'Elixir.Atom').
-define(bitwise, 'Elixir.Bitwise').
-define(enum, 'Elixir.Enum').
-define(float, 'Elixir.Float').
-define(function, 'Elixir.Function').
-define(integer, 'Elixir.Integer').
-define(io, 'Elixir.IO').
-define(kernel, 'Elixir.Kernel').
-define(list, 'Elixir.List').
-define(map, 'Elixir.Map').
-define(node, 'Elixir.Node').
-define(port, 'Elixir.Port').
-define(process, 'Elixir.Process').
-define(string, 'Elixir.String').
-define(string_chars, 'Elixir.String.Chars').
-define(system, 'Elixir.System').
-define(tuple, 'Elixir.Tuple').

% Macros used to define inline and rewrite rules.
% Defines the rules from Elixir function to Erlang function
% and the reverse, rewrites that are not reversible or have
% complex rules are defined without the macros.
-define(
  inline(ExMod, ExFun, Arity, ErlMod, ErlFun),
  inner_inline(ex_to_erl, ExMod, ExFun, Arity) -> {ErlMod, ErlFun};
  inner_inline(erl_to_ex, ErlMod, ErlFun, Arity) -> {ExMod, ExFun}
).

-define(
  rewrite(ExMod, ExFun, ExArgs, ErlMod, ErlFun, ErlArgs),
  inner_rewrite(ex_to_erl, _Meta, ExMod, ExFun, ExArgs) -> {ErlMod, ErlFun, ErlArgs};
  inner_rewrite(erl_to_ex, _Meta, ErlMod, ErlFun, ErlArgs) -> {ExMod, ExFun, ExArgs, fun(ErlArgs) -> ExArgs end}
).

erl_to_ex(Mod, Fun, Args) when is_list(Args) ->
  case inner_inline(erl_to_ex, Mod, Fun, length(Args)) of
    false -> inner_rewrite(erl_to_ex, [], Mod, Fun, Args);
    {ExMod, ExFun} -> {ExMod, ExFun, Args, fun identity/1}
  end;

erl_to_ex(Mod, Fun, Arity) when is_integer(Arity) ->
  inner_inline(erl_to_ex, Mod, Fun, Arity).

%% Inline rules
%%
%% Inline rules are straightforward, they keep the same
%% number and order of arguments and show up on captures.
inline(Mod, Fun, Arity) -> inner_inline(ex_to_erl, Mod, Fun, Arity).

?inline(?atom, to_charlist, 1, erlang, atom_to_list);
?inline(?atom, to_string, 1, erlang, atom_to_binary);

?inline(?bitwise, 'bnot', 1, erlang, 'bnot');
?inline(?bitwise, 'band', 2, erlang, 'band');
?inline(?bitwise, 'bor', 2, erlang, 'bor');
?inline(?bitwise, 'bxor', 2, erlang, 'bxor');
?inline(?bitwise, 'bsl', 2, erlang, 'bsl');
?inline(?bitwise, 'bsr', 2, erlang, 'bsr');

?inline(?function, capture, 3, erlang, make_fun);
?inline(?function, info, 1, erlang, fun_info);
?inline(?function, info, 2, erlang, fun_info);

?inline(?integer, to_charlist, 1, erlang, integer_to_list);
?inline(?integer, to_charlist, 2, erlang, integer_to_list);
?inline(?integer, to_string, 1, erlang, integer_to_binary);
?inline(?integer, to_string, 2, erlang, integer_to_binary);

?inline(?io, iodata_length, 1, erlang, iolist_size);
?inline(?io, iodata_to_binary, 1, erlang, iolist_to_binary);

?inline(?kernel, '!=', 2, erlang, '/=');
?inline(?kernel, '!==', 2, erlang, '=/=');
?inline(?kernel, '*', 2, erlang, '*');
?inline(?kernel, '+', 1, erlang, '+');
?inline(?kernel, '+', 2, erlang, '+');
?inline(?kernel, '++', 2, erlang, '++');
?inline(?kernel, '-', 1, erlang, '-');
?inline(?kernel, '-', 2, erlang, '-');
?inline(?kernel, '--', 2, erlang, '--');
?inline(?kernel, '/', 2, erlang, '/');
?inline(?kernel, '<', 2, erlang, '<');
?inline(?kernel, '<=', 2, erlang, '=<');
?inline(?kernel, '==', 2, erlang, '==');
?inline(?kernel, '===', 2, erlang, '=:=');
?inline(?kernel, '>', 2, erlang, '>');
?inline(?kernel, '>=', 2, erlang, '>=');
?inline(?kernel, abs, 1, erlang, abs);
?inline(?kernel, apply, 2, erlang, apply);
?inline(?kernel, apply, 3, erlang, apply);
?inline(?kernel, binary_part, 3, erlang, binary_part);
?inline(?kernel, bit_size, 1, erlang, bit_size);
?inline(?kernel, byte_size, 1, erlang, byte_size);
?inline(?kernel, ceil, 1, erlang, ceil);
?inline(?kernel, 'div', 2, erlang, 'div');
?inline(?kernel, exit, 1, erlang, exit);
?inline(?kernel, floor, 1, erlang, floor);
?inline(?kernel, 'function_exported?', 3, erlang, function_exported);
?inline(?kernel, hd, 1, erlang, hd);
?inline(?kernel, is_atom, 1, erlang, is_atom);
?inline(?kernel, is_binary, 1, erlang, is_binary);
?inline(?kernel, is_bitstring, 1, erlang, is_bitstring);
?inline(?kernel, is_boolean, 1, erlang, is_boolean);
?inline(?kernel, is_float, 1, erlang, is_float);
?inline(?kernel, is_function, 1, erlang, is_function);
?inline(?kernel, is_function, 2, erlang, is_function);
?inline(?kernel, is_integer, 1, erlang, is_integer);
?inline(?kernel, is_list, 1, erlang, is_list);
?inline(?kernel, is_map, 1, erlang, is_map);
?inline(?kernel, is_number, 1, erlang, is_number);
?inline(?kernel, is_pid, 1, erlang, is_pid);
?inline(?kernel, is_port, 1, erlang, is_port);
?inline(?kernel, is_reference, 1, erlang, is_reference);
?inline(?kernel, is_tuple, 1, erlang, is_tuple);
?inline(?kernel, length, 1, erlang, length);
?inline(?kernel, make_ref, 0, erlang, make_ref);
?inline(?kernel, map_size, 1, erlang, map_size);
?inline(?kernel, max, 2, erlang, max);
?inline(?kernel, min, 2, erlang, min);
?inline(?kernel, node, 0, erlang, node);
?inline(?kernel, node, 1, erlang, node);
?inline(?kernel, 'not', 1, erlang, 'not');
?inline(?kernel, 'rem', 2, erlang, 'rem');
?inline(?kernel, round, 1, erlang, round);
?inline(?kernel, self, 0, erlang, self);
?inline(?kernel, send, 2, erlang, send);
?inline(?kernel, spawn, 1, erlang, spawn);
?inline(?kernel, spawn, 3, erlang, spawn);
?inline(?kernel, spawn_link, 1, erlang, spawn_link);
?inline(?kernel, spawn_link, 3, erlang, spawn_link);
?inline(?kernel, spawn_monitor, 1, erlang, spawn_monitor);
?inline(?kernel, spawn_monitor, 3, erlang, spawn_monitor);
?inline(?kernel, throw, 1, erlang, throw);
?inline(?kernel, tl, 1, erlang, tl);
?inline(?kernel, trunc, 1, erlang, trunc);
?inline(?kernel, tuple_size, 1, erlang, tuple_size);

?inline(?list, to_atom, 1, erlang, list_to_atom);
?inline(?list, to_existing_atom, 1, erlang, list_to_existing_atom);
?inline(?list, to_float, 1, erlang, list_to_float);
?inline(?list, to_integer, 1, erlang, list_to_integer);
?inline(?list, to_integer, 2, erlang, list_to_integer);
?inline(?list, to_tuple, 1, erlang, list_to_tuple);

?inline(?map, from_keys, 2, maps, from_keys);
?inline(?map, intersect, 2, maps, intersect);
?inline(?map, keys, 1, maps, keys);
?inline(?map, merge, 2, maps, merge);
?inline(?map, to_list, 1, maps, to_list);
?inline(?map, values, 1, maps, values);

?inline(?node, list, 0, erlang, nodes);
?inline(?node, list, 1, erlang, nodes);
?inline(?node, spawn, 2, erlang, spawn);
?inline(?node, spawn, 3, erlang, spawn_opt);
?inline(?node, spawn, 4, erlang, spawn);
?inline(?node, spawn, 5, erlang, spawn_opt);
?inline(?node, spawn_link, 2, erlang, spawn_link);
?inline(?node, spawn_link, 4, erlang, spawn_link);
?inline(?node, spawn_monitor, 2, erlang, spawn_monitor);
?inline(?node, spawn_monitor, 4, erlang, spawn_monitor);

?inline(?port, close, 1, erlang, port_close);
?inline(?port, command, 2, erlang, port_command);
?inline(?port, command, 3, erlang, port_command);
?inline(?port, connect, 2, erlang, port_connect);
?inline(?port, list, 0, erlang, ports);
?inline(?port, open, 2, erlang, open_port);

?inline(?process, alias, 0, erlang, alias);
?inline(?process, alias, 1, erlang, alias);
?inline(?process, 'alive?', 1, erlang, is_process_alive);
?inline(?process, cancel_timer, 1, erlang, cancel_timer);
?inline(?process, cancel_timer, 2, erlang, cancel_timer);
?inline(?process, demonitor, 1, erlang, demonitor);
?inline(?process, demonitor, 2, erlang, demonitor);
?inline(?process, exit, 2, erlang, exit);
?inline(?process, flag, 2, erlang, process_flag);
?inline(?process, flag, 3, erlang, process_flag);
?inline(?process, get, 0, erlang, get);
?inline(?process, get_keys, 0, erlang, get_keys);
?inline(?process, get_keys, 1, erlang, get_keys);
?inline(?process, group_leader, 0, erlang, group_leader);
?inline(?process, hibernate, 3, erlang, hibernate);
?inline(?process, link, 1, erlang, link);
?inline(?process, list, 0, erlang, processes);
?inline(?process, read_timer, 1, erlang, read_timer);
?inline(?process, registered, 0, erlang, registered);
?inline(?process, send, 3, erlang, send);
?inline(?process, spawn, 2, erlang, spawn_opt);
?inline(?process, spawn, 4, erlang, spawn_opt);
?inline(?process, unalias, 1, erlang, unalias);
?inline(?process, unlink, 1, erlang, unlink);
?inline(?process, unregister, 1, erlang, unregister);

?inline(?string, duplicate, 2, binary, copy);
?inline(?string, to_atom, 1, erlang, binary_to_atom);
?inline(?string, to_existing_atom, 1, erlang, binary_to_existing_atom);
?inline(?string, to_float, 1, erlang, binary_to_float);
?inline(?string, to_integer, 1, erlang, binary_to_integer);
?inline(?string, to_integer, 2, erlang, binary_to_integer);

?inline(?system, monotonic_time, 0, erlang, monotonic_time);
?inline(?system, os_time, 0, os, system_time);
?inline(?system, system_time, 0, erlang, system_time);
?inline(?system, time_offset, 0, erlang, time_offset);
?inline(?system, unique_integer, 0, erlang, unique_integer);
?inline(?system, unique_integer, 1, erlang, unique_integer);
?inline(?tuple, to_list, 1, erlang, tuple_to_list);

% Defined without macro to avoid conflict with Bitwise named operators
inner_inline(ex_to_erl, ?bitwise, '~~~', 1) -> {erlang, 'bnot'};
inner_inline(ex_to_erl, ?bitwise, '&&&', 2) -> {erlang, 'band'};
inner_inline(ex_to_erl, ?bitwise, '|||', 2) -> {erlang, 'bor'};
inner_inline(ex_to_erl, ?bitwise, '^^^', 2) -> {erlang, 'bxor'};
inner_inline(ex_to_erl, ?bitwise, '<<<', 2) -> {erlang, 'bsl'};
inner_inline(ex_to_erl, ?bitwise, '>>>', 2) -> {erlang, 'bsr'};

% Defined without macro to avoid conflict with Process.demonitor
inner_inline(ex_to_erl, ?port, demonitor, 1) -> {erlang, demonitor};
inner_inline(ex_to_erl, ?port, demonitor, 2) -> {erlang, demonitor};

inner_inline(_, _, _, _) -> false.

%% Rewrite rules
%%
%% Rewrite rules are more complex than regular inlining code
%% as they may change the number of arguments. However, they
%% don't add new code (such as case expressions), at best they
%% perform dead code removal.
rewrite(?string_chars, DotMeta, to_string, Meta, [Arg]) ->
  case is_always_string(Arg) of
    true -> Arg;
    false -> {{'.', DotMeta, [?string_chars, to_string]}, Meta, [Arg]}
  end;
rewrite(erlang, _, '+', _, [Arg]) when is_number(Arg) -> +Arg;
rewrite(erlang, _, '-', _, [Arg]) when is_number(Arg) -> -Arg;
rewrite(Receiver, DotMeta, Right, Meta, Args) ->
  {EReceiver, ERight, EArgs} = inner_rewrite(ex_to_erl, DotMeta, Receiver, Right, Args),
  {{'.', DotMeta, [EReceiver, ERight]}, Meta, EArgs}.

?rewrite(?float, to_charlist, [Arg], erlang, float_to_list, [Arg, [short]]);
?rewrite(?float, to_string, [Arg], erlang, float_to_binary, [Arg, [short]]);
?rewrite(?kernel, is_map_key, [Map, Key], erlang, is_map_key, [Key, Map]);
?rewrite(?map, delete, [Map, Key], maps, remove, [Key, Map]);
?rewrite(?map, fetch, [Map, Key], maps, find, [Key, Map]);
?rewrite(?map, 'fetch!', [Map, Key], maps, get, [Key, Map]);
?rewrite(?map, 'has_key?', [Map, Key], maps, is_key, [Key, Map]);
?rewrite(?map, put, [Map, Key, Value], maps, put, [Key, Value, Map]);
?rewrite(?map, 'replace!', [Map, Key, Value], maps, update, [Key, Value, Map]);
?rewrite(?port, monitor, [Arg], erlang, monitor, [port, Arg]);
?rewrite(?process, group_leader, [Pid, Leader], erlang, group_leader, [Leader, Pid]);
?rewrite(?process, monitor, [Arg], erlang, monitor, [process, Arg]);
?rewrite(?process, monitor, [Arg, Opts], erlang, monitor, [process, Arg, Opts]);
?rewrite(?process, send_after, [Dest, Msg, Time], erlang, send_after, [Time, Dest, Msg]);
?rewrite(?process, send_after, [Dest, Msg, Time, Opts], erlang, send_after, [Time, Dest, Msg, Opts]);
?rewrite(?tuple, duplicate, [Data, Size], erlang, make_tuple, [Size, Data]);

inner_rewrite(ex_to_erl, Meta, ?tuple, delete_at, [Tuple, Index]) ->
  {erlang, delete_element, [increment(Meta, Index), Tuple]};
inner_rewrite(ex_to_erl, Meta, ?tuple, insert_at, [Tuple, Index, Term]) ->
  {erlang, insert_element, [increment(Meta, Index), Tuple, Term]};
inner_rewrite(ex_to_erl, Meta, ?kernel, elem, [Tuple, Index]) ->
  {erlang, element, [increment(Meta, Index), Tuple]};
inner_rewrite(ex_to_erl, Meta, ?kernel, put_elem, [Tuple, Index, Value]) ->
  {erlang, setelement, [increment(Meta, Index), Tuple, Value]};

inner_rewrite(erl_to_ex, _Meta, erlang, delete_element, [Index, Tuple]) when is_number(Index) ->
  {?tuple, delete_at, [Tuple, Index - 1], fun([Index, Tuple]) -> [Tuple, Index] end};
inner_rewrite(erl_to_ex, _Meta, erlang, insert_element, [Index, Tuple, Term]) when is_number(Index) ->
  {?tuple, insert_at, [Tuple, Index - 1, Term], fun([Index, Tuple, Term]) -> [Tuple, Index, Term] end};
inner_rewrite(erl_to_ex, _Meta, erlang, element, [Index, Tuple]) when is_number(Index) ->
  {?kernel, elem, [Tuple, Index - 1], fun([Index, Tuple]) -> [Tuple, Index] end};
inner_rewrite(erl_to_ex, _Meta, erlang, setelement, [Index, Tuple, Term]) when is_number(Index) ->
  {?kernel, put_elem, [Tuple, Index - 1, Term], fun([Index, Tuple, Term]) -> [Tuple, Index, Term] end};

inner_rewrite(erl_to_ex, _Meta, erlang, delete_element, [{{'.', _, [erlang, '+']}, _, [Index, 1]}, Tuple]) ->
  {?tuple, delete_at, [Tuple, Index], fun([Index, Tuple]) -> [Tuple, Index] end};
inner_rewrite(erl_to_ex, _Meta, erlang, insert_element, [{{'.', _, [erlang, '+']}, _, [Index, 1]}, Tuple, Term]) ->
  {?tuple, insert_at, [Tuple, Index, Term], fun([Index, Tuple, Term]) -> [Tuple, Index, Term] end};
inner_rewrite(erl_to_ex, _Meta, erlang, element, [{{'.', _, [erlang, '+']}, _, [Index, 1]}, Tuple]) ->
  {?kernel, elem, [Tuple, Index], fun([Index, Tuple]) -> [Tuple, Index] end};
inner_rewrite(erl_to_ex, _Meta, erlang, setelement, [{{'.', _, [erlang, '+']}, _, [Index, 1]}, Tuple, Term]) ->
  {?kernel, put_elem, [Tuple, Index, Term], fun([Index, Tuple, Term]) -> [Tuple, Index, Term] end};

inner_rewrite(erl_to_ex, _Meta, erlang, 'orelse', [_, _] = Args) ->
  {?kernel, 'or', Args, fun identity/1};
inner_rewrite(erl_to_ex, _Meta, erlang, 'andalso', [_, _] = Args) ->
  {?kernel, 'and', Args, fun identity/1};

inner_rewrite(ex_to_erl, _Meta, Mod, Fun, Args) -> {Mod, Fun, Args};
inner_rewrite(erl_to_ex, _Meta, Mod, Fun, Args) -> {Mod, Fun, Args, fun identity/1}.

identity(Arg) -> Arg.

increment(_Meta, Number) when is_number(Number) ->
  Number + 1;
increment(Meta, Other) ->
  {{'.', Meta, [erlang, '+']}, Meta, [Other, 1]}.

%% Match rewrite
%%
%% Match rewrite is similar to regular rewrite, except
%% it also verifies the rewrite rule applies in a match context.
%% The allowed operations are very limited.
%% The Kernel operators are already inlined by now, we only need to
%% care about Erlang ones.
match(erlang, _, '++', Meta, [Left, Right], _S) ->
  try {ok, static_append(Left, Right, Meta)}
  catch impossible -> {error, {invalid_match_append, Left}}
  end;
match(Receiver, _, Right, _, Args, _S) ->
  {error, {invalid_match, Receiver, Right, length(Args)}}.

static_append([], Right, _Meta) -> Right;
static_append([{'|', InnerMeta, [Head, Tail]}], Right, Meta) when is_list(Tail) ->
  [{'|', InnerMeta, [Head, static_append(Tail, Right, Meta)]}];
static_append([{'|', _, [_, _]}], _, _) -> throw(impossible);
static_append([Last], Right, Meta) -> [{'|', Meta, [Last, Right]}];
static_append([Head | Tail], Right, Meta) -> [Head | static_append(Tail, Right, Meta)];
static_append(_, _, _) -> throw(impossible).

%% Guard rewrite
%%
%% Guard rewrite is similar to regular rewrite, except
%% it also verifies the resulting function is supported in
%% guard context - only certain BIFs and operators are.
guard(Receiver, DotMeta, Right, Meta, Args, S) ->
  case inner_rewrite(ex_to_erl, DotMeta, Receiver, Right, Args) of
    {erlang, RRight, RArgs} ->
      case allowed_guard(RRight, length(RArgs)) of
        true -> {ok, {{'.', DotMeta, [erlang, RRight]}, Meta, RArgs}};
        false -> {error, {invalid_guard, Receiver, Right, length(Args), elixir_utils:guard_info(S)}}
      end;
    _ -> {error, {invalid_guard, Receiver, Right, length(Args), elixir_utils:guard_info(S)}}
  end.

%% erlang:is_record/2-3 are compiler guards in Erlang which we
%% need to explicitly forbid as they are allowed in erl_internal.
allowed_guard(is_record, 2) -> false;
allowed_guard(is_record, 3) -> false;
allowed_guard(Right, Arity) ->
  erl_internal:guard_bif(Right, Arity) orelse elixir_utils:guard_op(Right, Arity).

format_error({invalid_guard, Receiver, Right, Arity, Context}) ->
  io_lib:format(cannot_invoke_or_maybe_require(Receiver, Right, Arity) ++ " ~ts.~ts/~B inside a ~ts",
                ['Elixir.Macro':to_string(Receiver), Right, Arity, Context]);
format_error({invalid_match, Receiver, Right, Arity}) ->
  io_lib:format(cannot_invoke_or_maybe_require(Receiver, Right, Arity) ++ " ~ts.~ts/~B inside a match",
                ['Elixir.Macro':to_string(Receiver), Right, Arity]);
format_error({invalid_match_append, Arg}) ->
  io_lib:format("invalid argument for ++ operator inside a match, expected a literal proper list, got: ~ts",
                ['Elixir.Macro':to_string(Arg)]).

cannot_invoke_or_maybe_require(Receiver, Fun, Arity) ->
  try
    true = lists:member({Fun, Arity}, Receiver:'__info__'(macros)),
    ["you must require the module", 'Elixir.Macro':to_string(Receiver), " before invoking macro"]
  catch
    _:_ -> "cannot invoke remote function"
  end.

is_always_string({{'.', _, [Module, Function]}, _, Args}) ->
  is_always_string(Module, Function, length(Args));
is_always_string(Ast) ->
  is_binary(Ast).

is_always_string('Elixir.Enum', join, _) -> true;
is_always_string('Elixir.Enum', map_join, _) -> true;
is_always_string('Elixir.Kernel', inspect, _) -> true;
is_always_string('Elixir.Macro', to_string, _) -> true;
is_always_string('Elixir.String.Chars', to_string, _) -> true;
is_always_string('Elixir.Path', join, _) -> true;
is_always_string(_Module, _Function, _Args) -> false.
