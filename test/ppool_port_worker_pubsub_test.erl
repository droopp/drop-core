-module(ppool_port_worker_pubsub_test).
-include_lib("eunit/include/eunit.hrl").

-define(WORKER, port_worker).
-define(MOD1, {"./test/workers/port_worker 0 2>/dev/null", 100}).

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

          ppool:start_pool(ppool, {p1, 1, {?WORKER, start_link, []} }),
          ppool:start_pool(ppool, {s1, 1, {?WORKER, start_link, []} }),
          ppool:start_pool(ppool, {p2, 2, {?WORKER, start_link, []} }),
          ppool:start_pool(ppool, {s2, 2, {?WORKER, start_link, []} }),
 

         P1=ppool_worker:start_all_workers(p1, ?MOD1),
          ?assert(P1=={ok, full_limit}),

         P2=ppool_worker:start_all_workers(p2, ?MOD1),
          ?assert(P2=={ok, full_limit}),

         S1=ppool_worker:start_all_workers(s1, ?MOD1),
          ?assert(S1=={ok, full_limit}),

         S2=ppool_worker:start_all_workers(s2, ?MOD1),
          ?assert(S2=={ok, full_limit}),

          timer:sleep(200)


      end,
      fun(_) ->

         P1=ppool_worker:stop_all_workers(p1),
          ?assert(P1==ok),

         P2=ppool_worker:stop_all_workers(p2),
          ?assert(P2==ok),

         P3=ppool_worker:stop_all_workers(s1),
          ?assert(P3==ok),

         P4=ppool_worker:stop_all_workers(s2),
          ?assert(P4==ok),


       ppool:stop_pool(ppool, p1),
       ppool:stop_pool(ppool, p2),
       ppool:stop_pool(ppool, s1),
       ppool:stop_pool(ppool, s2)



      end,
      run_tests()

     }
    }.

run_tests() ->
    [
     {"sub 1 to 1",
        fun() ->

            R=ppool_worker:subscribe(p1, {s1, <<"no">>, one}),
              ?assert(R=:=ok),

            R=ppool_worker:cast_worker(p1, <<"request1\n">>),
              ?assert(R=:=ok),

            timer:sleep(50),

              [{worker_stat,_,
                            no,_,p1,Req,Status,
                            Res,
                            _,
                            _}] = ets:tab2list(p1),

             ?assert(Status=:=ok),
              ?assert(Req=:=<<"request1\n">>),
               ?assert(Res=:=[<<"ok">>]),

              [{worker_stat,_,
                            _,_,s1,Req2,Status2,
                            Res2,
                            _,
                            _}] = ets:tab2list(s1),

             ?assert(Status2=:=ok),
              ?assert(Req2=:=<<"ok\n">>),
               ?assert(Res2=:=[<<"ok">>]),

            %% unsubscribe

            R=ppool_worker:unsubscribe(p1, s1),
              ?assert(R=:=ok),

            R=ppool_worker:cast_worker(p1, <<"request1\n">>),
              ?assert(R=:=ok),

            timer:sleep(50),

              [_, {worker_stat,_,
                            no,_,p1,Req,Status,
                            Res,
                            _,
                            _}] = ets:tab2list(p1),

             ?assert(Status=:=ok),
              ?assert(Req=:=<<"request1\n">>),
               ?assert(Res=:=[<<"ok">>]),

              [{worker_stat,_,
                            _,_,s1,Req2,Status2,
                            Res2,
                            _,
                            _}] = ets:tab2list(s1),

             ?assert(Status2=:=ok),
              ?assert(Req2=:=<<"ok\n">>),
               ?assert(Res2=:=[<<"ok">>])

        end
     },

     {"sub 1 to all",
        fun() ->

            R=ppool_worker:subscribe(p1, {s2, <<"no">>, all}),
              ?assert(R=:=ok),

            R=ppool_worker:cast_worker(p1, <<"request1\n">>),
              ?assert(R=:=ok),

            timer:sleep(50),

              [{worker_stat,_,
                            no,_,p1,Req,Status,
                            Res,
                            _,
                            _}] = ets:tab2list(p1),

             ?assert(Status=:=ok),
              ?assert(Req=:=<<"request1\n">>),
               ?assert(Res=:=[<<"ok">>]),

              [{worker_stat,_,
                            _,_,s2,Req2,Status2,
                            Res2,
                            _,
                            _}, 
              
              {worker_stat,_,
                            _,_,s2,Req3,Status3,
                            Res3,
                            _,
                            _}

              ] = ets:tab2list(s2),

             ?assert(Status2=:=ok),
              ?assert(Req2=:=<<"ok\n">>),
               ?assert(Res2=:=[<<"ok">>]),


             ?assert(Status3=:=ok),
              ?assert(Req3=:=<<"ok\n">>),
               ?assert(Res3=:=[<<"ok">>]),


            %% unsubscribe

            R=ppool_worker:unsubscribe(p1, s2),
              ?assert(R=:=ok),

            R=ppool_worker:cast_worker(p1, <<"request1\n">>),
              ?assert(R=:=ok),

            timer:sleep(50),

              [_, {worker_stat,_,
                            no,_,p1,Req,Status,
                            Res,
                            _,
                            _}] = ets:tab2list(p1),

             ?assert(Status=:=ok),
              ?assert(Req=:=<<"request1\n">>),
               ?assert(Res=:=[<<"ok">>]),

              [{worker_stat,_,
                            _,_,s2,Req2,Status2,
                            Res2,
                            _,
                            _}, _] = ets:tab2list(s2),

             ?assert(Status2=:=ok),
              ?assert(Req2=:=<<"ok\n">>),
               ?assert(Res2=:=[<<"ok">>])

        end
     },

     {"sub 1 to dall",
        fun() ->

            R=ppool_worker:subscribe(p1, {s2, <<"no">>, dall}),
              ?assert(R=:=ok),

            R=ppool_worker:cast_worker(p1, <<"request1\n">>),
              ?assert(R=:=ok),

            timer:sleep(50),

              [{worker_stat,_,
                            no,_,p1,Req,Status,
                            Res,
                            _,
                            _}] = ets:tab2list(p1),

             ?assert(Status=:=ok),
              ?assert(Req=:=<<"request1\n">>),
               ?assert(Res=:=[<<"ok">>]),

              [{worker_stat,_,
                            _,_,s2,Req2,Status2,
                            Res2,
                            _,
                            _} 
              ] = ets:tab2list(s2),

             ?assert(Status2=:=ok),
              ?assert(Req2=:=<<"ok\n">>),
               ?assert(Res2=:=[<<"ok">>]),

            %% unsubscribe

            R=ppool_worker:unsubscribe(p1, s2),
              ?assert(R=:=ok),

            R=ppool_worker:cast_worker(p1, <<"request1\n">>),
              ?assert(R=:=ok),

            timer:sleep(50),

              [_, {worker_stat,_,
                            no,_,p1,Req,Status,
                            Res,
                            _,
                            _}] = ets:tab2list(p1),

             ?assert(Status=:=ok),
              ?assert(Req=:=<<"request1\n">>),
               ?assert(Res=:=[<<"ok">>]),

              [{worker_stat,_,
                            _,_,s2,Req2,Status2,
                            Res2,
                            _,
                            _}] = ets:tab2list(s2),

             ?assert(Status2=:=ok),
              ?assert(Req2=:=<<"ok\n">>),
               ?assert(Res2=:=[<<"ok">>])

        end
     },

     {"sub 1 to 1 with filter",
        fun() ->

            R=ppool_worker:subscribe(p1, {s1, <<"ok">>, one}),
              ?assert(R=:=ok),

            R=ppool_worker:cast_worker(p1, <<"request1\n">>),
              ?assert(R=:=ok),

            timer:sleep(50),

              [{worker_stat,_,
                            no,_,p1,Req,Status,
                            Res,
                            _,
                            _}] = ets:tab2list(p1),

             ?assert(Status=:=ok),
              ?assert(Req=:=<<"request1\n">>),
               ?assert(Res=:=[<<"ok">>]),

              [{worker_stat,_,
                            _,_,s1,Req2,Status2,
                            Res2,
                            _,
                            _}] = ets:tab2list(s1),

             ?assert(Status2=:=ok),
              ?assert(Req2=:=<<"ok\n">>),
               ?assert(Res2=:=[<<"ok">>])

     end

     },
     {"sub 1 to 1 with non filter",
        fun() ->

            R=ppool_worker:subscribe(p1, {s1, <<"nonexist">>, one}),
              ?assert(R=:=ok),

            R=ppool_worker:cast_worker(p1, <<"request1\n">>),
              ?assert(R=:=ok),

            timer:sleep(50),

              [{worker_stat,_,
                            no,_,p1,Req,Status,
                            Res,
                            _,
                            _}] = ets:tab2list(p1),

             ?assert(Status=:=ok),
              ?assert(Req=:=<<"request1\n">>),
               ?assert(Res=:=[<<"ok">>]),

              Res2 = ets:tab2list(s1),

             ?assert(Res2=:=[])

     end

     }




    ].


