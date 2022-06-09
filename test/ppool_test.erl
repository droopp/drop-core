-module(ppool_test).
-include_lib("eunit/include/eunit.hrl").

%%-compile(export_all).

ppool_test_() ->
    {"Example test",
    {setup,
     fun() ->
        ?debugFmt("setup", []),

        application:start(drop)
   
     end,
     fun(_) ->

        ?debugFmt("tearDown", []),
        application:stop(drop)

     end,
     {
      foreach,
      fun() ->

        ?debugFmt("forEach start", []),
 
              io:format("start")


      end,
      fun(_) ->

        ?debugFmt("forEach stop", [])

      end,
      basic_tests()

     }
    }}.


basic_tests() ->
    [
     {"start_worker",
        fun() ->
        ?debugFmt("func test", []),


                P1 = 1,
                P2 = 2,

                ?assert(P1=/=P2)
        end
     },

     {"start_worker2",
        fun() ->
        ?debugFmt("func test", []),


                P1 = 1,
                P2 = 2,

                ?assert(P1=/=P2)
        end
     }


    ].

