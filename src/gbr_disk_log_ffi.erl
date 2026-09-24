-module(gbr_disk_log_ffi).

-export([result_normalize/1]).

result_normalize(ok) -> {ok, nil};
result_normalize({ok}) -> {ok, nil};
result_normalize(error) -> {error, nil};
result_normalize({error}) -> {error, nil};
result_normalize({ok, Val}) -> {ok, Val};
result_normalize({error, Reason}) -> {error, Reason};
result_normalize(Val) -> {ok, Val}.
