%%
%% Erlang worker example 
%% Use with worker type for internal modules
%%

-module(sys_pipe).
-export([start_pipe/1]).

-include("../../src/ppool.hrl").


start_pipe(F) ->
    receive

        Msg0 ->

           Msg = binary:part(Msg0, {0, byte_size(Msg0)-1}),
            Msgs = binary:split(Msg, ?SPLIT_MSG_SEQ, [global]),
             ?Debug({recv, Msgs}),

             R = for(fun(M) -> 
                              call_worker(M) 
                     end,  
                     Msgs),

             ?Debug({result, R}), 

             case R of
                 {error, Err} ->
                    F!{self(), {data, [Err]}};
                 _ ->
                    F!{self(), {data, [<<"ok">>]}}
             end,
 
             start_pipe(F)

    end.


%%
%% Custom loop with return
%%


for(F, R) ->
    for(F, R, []).

for(_, [], Acc) ->
    lists:reverse(Acc);

for(F, [H|T], Acc) ->
    R = F(H),

    case R of
        {stop, Res} ->
            {error, Res};

        {ok, Res} ->
            for(F, T, [Res|Acc])

    end.


call_worker(M) ->
    ?Debug({msg, M}),

    [N, I, O] = binary:split(M, <<"::">>, [global]),
     R = ppool_worker:call_sync_worker(erlang:binary_to_atom(N, latin1), 
                                 [I] ++ <<"\n">>),

     case R of
         {ok, {ok, [Res]}} ->

                case binary:match(Res, O) of
                    nomatch -> {stop, Res};
                    _ -> {ok, Res}
                end;

         _Any ->
             {stop, << <<"no_pool: ">>/binary, N/binary >> }
     end.
 
