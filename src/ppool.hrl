

-ifdef(trace).
    -define(Trace(M), io:format("TRACE: ~p~n", [M])).
-else.
    -define(Trace(M), void).
-endif.

-ifdef(debug).
    -define(Debug(M), io:format("DEBUG: ~p~n", [M])).
-else.
    -define(Debug(M), void).
-endif.

-ifdef(info).
    -define(Info(M), io:format("INFO: ~p~n", [M])).
-else.
    -define(Info(M), void).
-endif.

-ifdef(warn).
    -define(Warn(M), io:format("WARN: ~p~n", [M])).
-else.
    -define(Warn(M), void).
-endif.

-ifdef(error).
    -define(Error(M), io:format("ERROR: ~p~n", [M])).
-else.
    -define(Error(M), void).
-endif.


-define(ERROR_TIMEOUT, 500).
-define(NO_MORE_PPOOL, node_collector).

-define(SPLIT_MSG_SEQ, <<"\tncm\t">>).

-record(worker_stat, {
          ref,
          ref_from,
          pid,
          cmd,
          req,
          status,
          result,
          time_start,
          time_end
}).


