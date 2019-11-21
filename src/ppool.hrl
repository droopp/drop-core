

-ifdef(debug).
    -define(Debug(M), io:format("~p~n", [M])).
-else.
    -define(Debug(M), void).
-endif.


-ifdef(debug1).
    -define(Debug1(M), io:format("~p~n", [M])).
-else.
    -define(Debug1(M), void).
-endif.

-ifdef(debug4).
    -define(Debug4(M), io:format("~p~n", [M])).
-else.
    -define(Debug4(M), void).
-endif.

-ifdef(debug44).
    -define(Debug44(M), io:format("~p~n", [M])).
-else.
    -define(Debug44(M), void).
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


