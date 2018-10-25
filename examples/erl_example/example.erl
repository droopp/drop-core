%%
%% Erlang worker example 
%% Use with worker type for internal modules
%%


-module(example).
-export([example/1]).


example(F) ->
    receive

        R -> timer:sleep(5000),
            io:format("spawn ~p~n", [R]),
            F!{self(), {data, [<<"ok">>]}}
 
             example(F)

    end.
