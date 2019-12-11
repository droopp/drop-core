%%
%% Erlang worker example 
%% Use with worker type for internal modules
%%


-module(logger_cassandra).
-export([format/2]).


format(F, A) ->

    {Event_Id} = A,
    receive

        R -> 

           Msg=erlang:list_to_binary(["{\"server_id\":\"",
                                        atom_to_list(node()),"\", \"event_id\":\"",
                                        atom_to_list(Event_Id), "\", 
                                        \"op\":\"write\", \"body\":\"", R, "\"}"]),

            
            io:format("spawn ~p~p~n", [Msg, A]),
            F!{self(), {data, [Msg]}},
 
             format(F, A)

    end.
