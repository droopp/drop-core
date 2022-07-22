-module(ppool_port_worker_stream_pubsub_test).
-include_lib("eunit/include/eunit.hrl").

-define(WORKER, port_worker).
-define(MOD1, {"./test/workers/port_worker_stream 100 2>/dev/null", 200}).
-define(MOD2, {"./test/workers/port_worker 100 2>/dev/null", 200}).


exec_call_test_() ->
    {setup,
     fun() ->
        application:start(ppool)
         %% code:load_abs("test/workers/erl_worker"),

     end,
     fun(_) ->

        application:stop(ppool)

     end,
     {
      foreach,
      fun() ->

          ppool:start_pool(ppool, {p1_stream, 1, {?WORKER, start_link, []} }),
          ppool:start_pool(ppool, {s1, 1, {?WORKER, start_link, []} }),

         P1=ppool_worker:start_all_workers(p1_stream, ?MOD1),
          ?assert(P1=={ok, full_limit}),

         S1=ppool_worker:start_all_workers(s1, ?MOD2),
          ?assert(S1=={ok, full_limit}),

          timer:sleep(200)

      end,
      fun(_) ->

         P1=ppool_worker:stop_all_workers(p1_stream),
          ?assert(P1==ok),

         P3=ppool_worker:stop_all_workers(s1),
          ?assert(P3==ok),

       ppool:stop_pool(ppool, p1_stream),
       ppool:stop_pool(ppool, s1),

          timer:sleep(200)


      end,
      run_tests()

     }
    }.

run_tests() ->
    [
     {"sub 1 to 1",
        fun() ->

            R=ppool_worker:subscribe(p1_stream, {s1, <<"no">>, one}),
              ?assert(R=:=ok),

            timer:sleep(150),

            Arr = ets:tab2list(s1),
            %% ?debugFmt("process state..~p~n", [Arr]),


                    Res = lists:filter(fun(I)-> case I of 
                                                            {_,_,_,_,_,<<"ok\n">>,_,_,_,_} -> true; 
                                                            _ -> false 
                                                        end 
                                               end, Arr), 

              ?assert(length(Res)=<2),

            %% unsubscribe

            R=ppool_worker:unsubscribe(p1_stream, s1),
              ?assert(R=:=ok),

            timer:sleep(300),


            Arr2 = ets:tab2list(s1),

            %% ?debugFmt("process state..~p~n", [Arr2]),



                    Res2 = lists:filter(fun(I)-> case I of 
                                                            {_,_,_,_,_,<<"ok\n">>,_,_,_,_} -> true; 
                                                            _ -> false 
                                                        end 
                                               end, Arr2), 

              ?assert(length(Res2)=<2)

        end
     },


     {"sub 1 to all",
        fun() ->


           R=ppool_worker:subscribe(p1_stream, {s1, <<"no">>, all}),
              ?assert(R=:=ok),

           timer:sleep(150),

            Arr = ets:tab2list(s1),
            %% ?debugFmt("process state..~p~n", [Arr]),


                    Res = lists:filter(fun(I)-> case I of 
                                                            {_,_,_,_,_,<<"ok\n">>,_,_,_,_} -> true; 
                                                            _ -> false 
                                                        end 
                                               end, Arr), 

              ?assert(length(Res)=<2),

            %% unsubscribe

            R=ppool_worker:unsubscribe(p1_stream, s1),
              ?assert(R=:=ok),

            timer:sleep(300),


            Arr2 = ets:tab2list(s1),

            %% ?debugFmt("process state..~p~n", [Arr2]),



                    Res2 = lists:filter(fun(I)-> case I of 
                                                            {_,_,_,_,_,<<"ok\n">>,_,_,_,_} -> true; 
                                                            _ -> false 
                                                        end 
                                               end, Arr2), 

              ?assert(length(Res2)=<2)

        end
     },


     {"sub 1 to 1 with filter",
        fun() ->

            R=ppool_worker:subscribe(p1_stream, {s1, <<"filter">>, one}),
              ?assert(R=:=ok),

            timer:sleep(150),

            %% P1 = ets:tab2list(p1_stream),
            %% ?debugFmt("process state..~p~n", [P1]),

            Arr = ets:tab2list(s1),
            %% ?debugFmt("process state..~p~n", [Arr]),


                    Res = lists:filter(fun(I)-> case I of 
                                                            {_,_,_,_,_,<<"ok\n">>,_,_,_,_} -> true; 
                                                            _ -> false 
                                                        end 
                                               end, Arr), 

              ?assert(length(Res)=:=0),

            %% unsubscribe

            R=ppool_worker:unsubscribe(p1_stream, s1),
              ?assert(R=:=ok),

            timer:sleep(100),

            R=ppool_worker:subscribe(p1_stream, {s1, <<"ok">>, one}),
              ?assert(R=:=ok),

            timer:sleep(150),


            Arr2 = ets:tab2list(s1),
            %% ?debugFmt("process state..~p~n", [Arr2]),



                    Res2 = lists:filter(fun(I)-> case I of 
                                                            {_,_,_,_,_,<<"ok\n">>,_,_,_,_} -> true; 
                                                            _ -> false 
                                                        end 
                                               end, Arr2), 

              ?assert(length(Res2)=<2)


        end
     }



    ].


