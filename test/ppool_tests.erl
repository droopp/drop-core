

-module(ppool_tests).
-include_lib("eunit/include/eunit.hrl").

-compile(export_all).

ppool_test_() ->
    {setup,
     fun() ->


        %% http api
        application:start(crypto),
        application:start(asn1),
        application:start(public_key),
        application:start(ssl),

        application:start(cowlib),
        application:start(ranch),
        application:start(cowboy),
        application:start(drop_api),

        application:start(ppool)
    
   
     end,
     fun(_) ->

        application:stop(ppool),

        %% http api
        application:stop(drop_api),
        application:stop(cowboy),
        application:stop(ranch),
        application:stop(cowlib),

        application:stop(ssl),
        application:stop(public_key),
        application:stop(asn1),
        application:stop(crypto)

     end,
     {
      foreach,
      fun() ->
              ppool:start_pool(ppool, {test, 10, 
                                       {port_worker, start_link, []}
                                      }
                              )
      end,
      fun(_) ->
              ppool:stop_pool(ppool, test)
      end,
      basic_tests()

     }
    }.


basic_tests() ->
    [
     {"start_worker",
     fun() ->
             P1 = 1,
             P2 = 2,

             ?assert(P1=/=P2)
     end
     }

    ].


for(N, Fun, {Pn, T}=Args) 
  when N>0 ->
    Fun(Pn, T),
    for(N-1, Fun, Args);

for(0, Fun, {Pn, T}) ->
    Fun(Pn, T).






