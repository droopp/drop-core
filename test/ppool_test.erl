-module(ppool_test).
-include_lib("eunit/include/eunit.hrl").

exec_test_() ->
    {setup,
     fun() ->
        application:start(ppool)
   
     end,
     fun(_) ->

        application:stop(ppool)

     end,
     {
      foreach,
      fun() ->
        ok

      end,
      fun(_) ->
        ok

      end,
      run_tests()

     }
    }.


run_tests() ->
    [
     {"create port_worker pool",
        fun() ->
            
                {R, _}=ppool:start_pool(ppool, {p1, 1, {port_worker, start_link, []} }),
                ?assert(R==ok)
        end
     },

     {"create port_worker pool again",
        fun() ->

               {error,{R,_}}=ppool:start_pool(ppool, {p1, 1, {port_worker, start_link, []} }),
                ?assert(R==already_started)
        end
     },


     {"check pg state",
        fun() ->
               Gr=pg:which_groups(),
               %% ?debugFmt("pg members...~p~n", [Gr]),

                ?assert(lists:member(p1, Gr)),
                 ?assert(lists:member(p1_ev, Gr))
 
        end
     },

     {"check port_worker pool limit",
        fun() ->
               Gr=pg:which_groups(),
               %% ?debugFmt("pg members...~p~n", [Gr]),

                ?assert(lists:member(p1, Gr)),
                 ?assert(lists:member(p1_ev, Gr))
 
        end
     },


     {"delete port_worker pool",
        fun() ->

                R=ppool:stop_pool(ppool, p1),
                ?assert(R==ok)
        end
     },

     {"check pg state after",
        fun() ->
               Gr=pg:which_groups(),
                ?assert(not lists:member(p1, Gr)),
                 ?assert(not lists:member(p1_ev, Gr))

        end
     },


     {"delete port_worker pool again",
        fun() ->

                R=ppool:stop_pool(ppool, p1),
                ?assert(R==ok)
        end
     }

    ].

