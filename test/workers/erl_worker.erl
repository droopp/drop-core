%%
%% Erlang test worker  
%%

-module(erl_worker).
-export([do_2000_ok/1, do_ok/1]).


do_ok(F) ->

    receive

        R ->
            io:format("spawn ~p~n", [R]),

              F!{self(), {data, [<<"ok">>]}},
 
                do_ok(F)

    end.


do_2000_ok(F) ->

    receive

        R -> timer:sleep(2000),
            io:format("spawn ~p~n", [R]),

              F!{self(), {data, [<<"ok">>]}},
 
                do_2000_ok(F)

    end.



