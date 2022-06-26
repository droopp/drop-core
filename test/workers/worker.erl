%%
%% Erlang test worker  
%%

-module(erl_worker).
-export([do_5000_ok/1]).

do_5000_ok(F) ->

    receive

        R -> timer:sleep(5000),
            io:format("spawn ~p~n", [R]),

              F!{self(), {data, [<<"ok">>]}},
 
                do_5000_ok(F)

    end.
