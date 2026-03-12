-module(gbr_disk_log_ffi).
-export([open/2, close/1, log/2, sync/1, chunk/2, start_continuation/0,
         async_log/2, binary_async_log/2, block/2, unblock/1, increment_wrap_file/1, info/1]).

%% Helpers to transform Gleam types into Erlang terms
%%

map_option(none, _F) -> nil;
map_option({some, Val}, F) -> F(Val).

map_log_repair(enable) -> true;
map_log_repair(truncate) -> truncate;
map_log_repair(disabled) -> false.

map_log_format(internal) -> internal;
map_log_format(external) -> external.

map_log_mode(read_only) -> read_only;
map_log_mode(read_write) -> read_write.

map_log_size(infinity) -> infinity;
map_log_size({max_bytes, Int}) -> Int;
map_log_size({wrap_size, MaxBytes, MaxFiles}) -> {MaxBytes, MaxFiles}.

%% Erlang terms to Gleam types
%%

unmap_log_type(halt) -> halt;
unmap_log_type(wrap) -> wrap;
unmap_log_type(rotate) -> rotate.

unmap_log_format(internal) -> internal;
unmap_log_format(external) -> external.

unmap_log_mode(read_only) -> read_only;
unmap_log_mode(read_write) -> read_write.

unmap_log_size(infinity) -> infinity;
unmap_log_size(Int) when is_integer(Int) -> {max_bytes, Int};
unmap_log_size({MaxBytes, MaxFiles}) -> {wrap_size, MaxBytes, MaxFiles}.

open(Name, {log_options, File, Repair, Type, Format, Size, Notify, Head, HeadFunc, Mode, Quiet}) ->
    Opts = [
        {name, Name},
        {file, map_option(File, fun(S) -> binary_to_list(S) end)},
        {repair, map_option(Repair, fun map_log_repair/1)},
        {type, map_option(Type, fun(T) -> T end)},
        {format, map_option(Format, fun map_log_format/1)},
        {size, map_option(Size, fun map_log_size/1)},
        {notify, map_option(Notify, fun(B) -> B end)},
        {head, map_option(Head, fun(H) -> H end)},
        {head_func, map_option(HeadFunc, fun(F) -> F end)},
        {mode, map_option(Mode, fun map_log_mode/1)},
        {quiet, map_option(Quiet, fun(Q) -> Q end)}
    ],
    ArgL = [{K, V} || {K, V} <- Opts, V /= nil],

    case disk_log:open(ArgL) of
        {ok, LogName} -> {ok, LogName};
        {reopened, LogName} -> {ok, LogName};
        {repaired, LogName, _Recovery, _BadBytes} -> {ok, LogName};
        {error, Reason} -> {error, disk_log:format_error(Reason)}
    end.

close(LogName) ->
    case disk_log:close(LogName) of
        ok -> {ok, LogName};
        {error, Reason} -> {error, disk_log:format_error(Reason)}
    end.

log(LogName, Data) ->
    case disk_log:log(LogName, Data) of
        ok -> {ok, LogName};
        {error, Reason} -> {error, disk_log:format_error(Reason)}
    end.

async_log(LogName, Data) ->
    case disk_log:alog(LogName, Data) of
        ok -> {ok, LogName};
        notify -> {ok, LogName};
        {error, Reason} -> {error, disk_log:format_error(Reason)}
    end.

binary_async_log(LogName, Data) ->
    case disk_log:balog(LogName, Data) of
        ok -> {ok, LogName};
        notify -> {ok, LogName};
        {error, Reason} -> {error, disk_log:format_error(Reason)}
    end.

sync(LogName) ->
    case disk_log:sync(LogName) of
        ok -> {ok, LogName};
        {error, Reason} -> {error, disk_log:format_error(Reason)}
    end.

chunk(LogName, {continuation, Continuation}) ->
    case disk_log:chunk(LogName, Continuation) of
        eof -> {ok, eof};
        {error, Reason} -> {error, disk_log:format_error(Reason)};
        {NextCont, Terms} -> {ok, {chunk, {continuation, NextCont}, Terms}};
        {NextCont, Terms, _BadBytes} -> {ok, {chunk, {continuation, NextCont}, Terms}}
    end.

block(LogName, Queue) ->
    case disk_log:block(LogName, Queue) of
        ok -> {ok, LogName};
        {error, Reason} -> {error, disk_log:format_error(Reason)}
    end.

unblock(LogName) ->
    case disk_log:unblock(LogName) of
        ok -> {ok, LogName};
        {error, Reason} -> {error, disk_log:format_error(Reason)}
    end.

increment_wrap_file(LogName) ->
    case disk_log:next_file(LogName) of
        {ok, LogName} -> {ok, LogName};
        {error, Reason} -> {error, disk_log:format_error(Reason)}
    end.

info(LogName) ->
    case disk_log:info(LogName) of
        {error, Reason} -> {error, disk_log:format_error(Reason)};
        InfoList when is_list(InfoList) ->
            Name = proplists:get_value(name, InfoList, LogName),
            File = proplists:get_value(file, InfoList, ""),
            Type = proplists:get_value(type, InfoList, halt),
            Format = proplists:get_value(format, InfoList, internal),
            Size = proplists:get_value(size, InfoList, infinity),
            Mode = proplists:get_value(mode, InfoList, read_write),

            {ok, {log_info,
                if is_atom(Name) -> atom_to_binary(Name, utf8); true -> Name end,
                if is_list(File) -> list_to_binary(File); true -> File end,
                unmap_log_type(Type),
                unmap_log_format(Format),
                unmap_log_size(Size),
                unmap_log_mode(Mode)
            }}
    end.

start_continuation() -> {continuation, start}.
