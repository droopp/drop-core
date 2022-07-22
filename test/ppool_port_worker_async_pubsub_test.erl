-module(ppool_port_worker_async_pubsub_test).
-include_lib("eunit/include/eunit.hrl").

-define(WORKER, port_worker).
-define(MOD1, {"./test/workers/port_worker_async 1 0 2>/dev/null", 100}).

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

          ppool:start_pool(ppool, {p1_async, 1, {?WORKER, start_link, []} }),
          ppool:start_pool(ppool, {s1_async, 1, {?WORKER, start_link, []} }),
          ppool:start_pool(ppool, {p2_async, 2, {?WORKER, start_link, []} }),
          ppool:start_pool(ppool, {s2_async, 2, {?WORKER, start_link, []} }),
 

         P1=ppool_worker:start_all_workers(p1_async, ?MOD1),
          ?assert(P1=={ok, full_limit}),

         P2=ppool_worker:start_all_workers(p2_async, ?MOD1),
          ?assert(P2=={ok, full_limit}),

         S1=ppool_worker:start_all_workers(s1_async, ?MOD1),
          ?assert(S1=={ok, full_limit}),

         S2=ppool_worker:start_all_workers(s2_async, ?MOD1),
          ?assert(S2=={ok, full_limit}),

          timer:sleep(200)


      end,
      fun(_) ->

         P1=ppool_worker:stop_all_workers(p1_async),
          ?assert(P1==ok),

         P2=ppool_worker:stop_all_workers(p2_async),
          ?assert(P2==ok),

         P3=ppool_worker:stop_all_workers(s1_async),
          ?assert(P3==ok),

         P4=ppool_worker:stop_all_workers(s2_async),
          ?assert(P4==ok),


       ppool:stop_pool(ppool, p1_async),
       ppool:stop_pool(ppool, p2_async),
       ppool:stop_pool(ppool, s1_async),
       ppool:stop_pool(ppool, s2_async)



      end,
      run_tests()

     }
    }.

run_tests() ->
    [
     {"sub 1 to 1",
        fun() ->

            R=ppool_worker:subscribe(p1_async, {s1_async, <<"no">>, one}),
              ?assert(R=:=ok),

            R=ppool_worker:cast_worker(p1_async, <<"request1\n">>),
              ?assert(R=:=ok),

            timer:sleep(50),

            Arr = ets:tab2list(p1_async),

              [{worker_stat,_,
                            no,_,p1_async,Req,Status,
                            Res,
                            _,
                            _}] = lists:filter(fun(I)-> case I of 
                                                            {_,_,_,_,_,<<"request1\n">>,_,_,_,_} -> true; 
                                                            _ -> false 
                                                        end 
                                               end, Arr), 

             ?assert(Status=:=ok),
              ?assert(Req=:=<<"request1\n">>),
               ?assert(Res=:=[<<"ok">>]),

            Arr2 = ets:tab2list(s1_async),

              [{worker_stat,_,
                            no,_,s1_async,Req2,Status2,
                            Res2,
                            _,
                            _}] = lists:filter(fun(I)-> case I of 
                                                            {_,_,_,_,_,<<"ok\n">>,_,_,_,_} -> true; 
                                                            _ -> false 
                                                        end 
                                               end, Arr2), 

             ?assert(Status2=:=ok),
              ?assert(Req2=:=<<"ok\n">>),
               ?assert(Res2=:=[<<"ok">>]),

            %% unsubscribe

            R=ppool_worker:unsubscribe(p1_async, s1_async),
              ?assert(R=:=ok),

            R=ppool_worker:cast_worker(p1_async, <<"request2\n">>),
              ?assert(R=:=ok),

            timer:sleep(50),

            Arr3 = ets:tab2list(p1_async),

              [{worker_stat,_,
                            no,_,p1_async,Req3,Status3,
                            Res3,
                            _,
                            _}] = lists:filter(fun(I)-> case I of 
                                                            {_,_,_,_,_,<<"request2\n">>,_,_,_,_} -> true; 
                                                            _ -> false 
                                                        end 
                                               end, Arr3), 
             ?assert(Status3=:=ok),
              ?assert(Req3=:=<<"request2\n">>),
               ?assert(Res3=:=[<<"ok">>]),


            Arr4 = ets:tab2list(s1_async),

                        Res4 = lists:filter(fun(I)-> case I of 
                                                            {_,_,_,_,_,<<"ok\n">>,_,_,_,_} -> true; 
                                                            _ -> false 
                                                        end 
                                               end, Arr4), 


              %% ?debugFmt("process state..~p~n", [Res4]),

              ?assert(length(Res4)=:=1)

        end
     },

     {"sub 1 to all",
        fun() ->

            R=ppool_worker:subscribe(p1_async, {s2_async, <<"no">>, all}),
              ?assert(R=:=ok),

            R=ppool_worker:cast_worker(p1_async, <<"request1\n">>),
              ?assert(R=:=ok),

            timer:sleep(50),

            Arr = ets:tab2list(p1_async),

              [{worker_stat,_,
                            no,_,p1_async,Req,Status,
                            Res,
                            _,
                            _}] = lists:filter(fun(I)-> case I of 
                                                            {_,_,_,_,_,<<"request1\n">>,_,_,_,_} -> true; 
                                                            _ -> false 
                                                        end 
                                               end, Arr), 

             ?assert(Status=:=ok),
              ?assert(Req=:=<<"request1\n">>),
               ?assert(Res=:=[<<"ok">>]),

  
              Arr4 = ets:tab2list(s2_async),

                        Res4 = lists:filter(fun(I)-> case I of 
                                                            {_,_,_,_,_,<<"ok\n">>,_,_,_,_} -> true; 
                                                            _ -> false 
                                                        end 
                                               end, Arr4), 


              %% ?debugFmt("process state..~p~n", [Res4]),

              ?assert(length(Res4)=:=2),

 
            %% unsubscribe

            R=ppool_worker:unsubscribe(p1_async, s2_async),
              ?assert(R=:=ok),

            R=ppool_worker:cast_worker(p1_async, <<"request2\n">>),
              ?assert(R=:=ok),

            timer:sleep(50),

 
            Arr2 = ets:tab2list(p1_async),

              [{worker_stat,_,
                            no,_,p1_async,Req2,Status2,
                            Res2,
                            _,
                            _}] = lists:filter(fun(I)-> case I of 
                                                            {_,_,_,_,_,<<"request2\n">>,_,_,_,_} -> true; 
                                                            _ -> false 
                                                        end 
                                               end, Arr2), 

             ?assert(Status2=:=ok),
              ?assert(Req2=:=<<"request2\n">>),
               ?assert(Res2=:=[<<"ok">>]),


              Arr4 = ets:tab2list(s2_async),

                        Res4 = lists:filter(fun(I)-> case I of 
                                                            {_,_,_,_,_,<<"ok\n">>,_,_,_,_} -> true; 
                                                            _ -> false 
                                                        end 
                                               end, Arr4), 


              %% ?debugFmt("process state..~p~n", [Res4]),

              ?assert(length(Res4)=:=2)

        end
     },

     {"sub 1 to dall",
        fun() ->

            R=ppool_worker:subscribe(p1_async, {s2_async, <<"no">>, dall}),
              ?assert(R=:=ok),

            R=ppool_worker:cast_worker(p1_async, <<"request1\n">>),
              ?assert(R=:=ok),

            timer:sleep(50),

            Arr = ets:tab2list(p1_async),

              [{worker_stat,_,
                            no,_,p1_async,Req,Status,
                            Res,
                            _,
                            _}] = lists:filter(fun(I)-> case I of 
                                                            {_,_,_,_,_,<<"request1\n">>,_,_,_,_} -> true; 
                                                            _ -> false 
                                                        end 
                                               end, Arr), 

             ?assert(Status=:=ok),
              ?assert(Req=:=<<"request1\n">>),
               ?assert(Res=:=[<<"ok">>]),

            Arr2 = ets:tab2list(s2_async),

              [{worker_stat,_,
                            no,_,s2_async,Req2,Status2,
                            Res2,
                            _,
                            _}] = lists:filter(fun(I)-> case I of 
                                                            {_,_,_,_,_,<<"ok\n">>,_,_,_,_} -> true; 
                                                            _ -> false 
                                                        end 
                                               end, Arr2), 


             ?assert(Status2=:=ok),
              ?assert(Req2=:=<<"ok\n">>),
               ?assert(Res2=:=[<<"ok">>]),

            %% unsubscribe

            R=ppool_worker:unsubscribe(p1_async, s2_async),
              ?assert(R=:=ok),

            R=ppool_worker:cast_worker(p1_async, <<"request2\n">>),
              ?assert(R=:=ok),

            timer:sleep(50),

            Arr3 = ets:tab2list(p1_async),

              [{worker_stat,_,
                            no,_,p1_async,Req3,Status3,
                            Res3,
                            _,
                            _}] = lists:filter(fun(I)-> case I of 
                                                            {_,_,_,_,_,<<"request2\n">>,_,_,_,_} -> true; 
                                                            _ -> false 
                                                        end 
                                               end, Arr3), 



             ?assert(Status3=:=ok),
              ?assert(Req3=:=<<"request2\n">>),
               ?assert(Res3=:=[<<"ok">>]),

            Arr4 = ets:tab2list(s2_async),

                        Res4 = lists:filter(fun(I)-> case I of 
                                                            {_,_,_,_,_,<<"ok\n">>,_,_,_,_} -> true; 
                                                            _ -> false 
                                                        end 
                                               end, Arr4), 


              %% ?debugFmt("process state..~p~n", [Res4]),

              ?assert(length(Res4)=:=1)


        end
     },

     {"sub 1 to 1 with filter",
        fun() ->

            R=ppool_worker:subscribe(p1_async, {s1_async, <<"ok">>, one}),
              ?assert(R=:=ok),

            R=ppool_worker:cast_worker(p1_async, <<"request1\n">>),
              ?assert(R=:=ok),

            timer:sleep(50),

            Arr = ets:tab2list(p1_async),

              [{worker_stat,_,
                            no,_,p1_async,Req,Status,
                            Res,
                            _,
                            _}] = lists:filter(fun(I)-> case I of 
                                                            {_,_,_,_,_,<<"request1\n">>,_,_,_,_} -> true; 
                                                            _ -> false 
                                                        end 
                                               end, Arr), 

             ?assert(Status=:=ok),
              ?assert(Req=:=<<"request1\n">>),
               ?assert(Res=:=[<<"ok">>]),

            Arr2 = ets:tab2list(s1_async),

              [{worker_stat,_,
                            no,_,s1_async,Req2,Status2,
                            Res2,
                            _,
                            _}] = lists:filter(fun(I)-> case I of 
                                                            {_,_,_,_,_,<<"ok\n">>,_,_,_,_} -> true; 
                                                            _ -> false 
                                                        end 
                                               end, Arr2), 


             ?assert(Status2=:=ok),
              ?assert(Req2=:=<<"ok\n">>),
               ?assert(Res2=:=[<<"ok">>])

 
     end

     },
     {"sub 1 to 1 with non filter",
        fun() ->

            R=ppool_worker:subscribe(p1_async, {s1_async, <<"nonexist">>, one}),
              ?assert(R=:=ok),

            R=ppool_worker:cast_worker(p1_async, <<"request1\n">>),
              ?assert(R=:=ok),

            timer:sleep(50),

            Arr = ets:tab2list(p1_async),

              [{worker_stat,_,
                            no,_,p1_async,Req,Status,
                            Res,
                            _,
                            _}] = lists:filter(fun(I)-> case I of 
                                                            {_,_,_,_,_,<<"request1\n">>,_,_,_,_} -> true; 
                                                            _ -> false 
                                                        end 
                                               end, Arr), 



             ?assert(Status=:=ok),
              ?assert(Req=:=<<"request1\n">>),
               ?assert(Res=:=[<<"ok">>]),

              Res2 = ets:tab2list(s1_async),

             ?assert(length(Res2)=:=1)

     end

     }




    ].


