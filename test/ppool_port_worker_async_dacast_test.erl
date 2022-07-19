-module(ppool_port_worker_async_dacast_test).
-include_lib("eunit/include/eunit.hrl").

-define(WORKER, port_worker).
-define(MOD1, {"./test/workers/port_worker_async 1 0 2>/dev/null", 100}).
-define(MOD2, {"./test/workers/port_worker_async 1 200 2>/dev/null", 300}).
-define(MOD3, {"./test/workers/port_worker_async 1 200 2>/dev/null", 100}).


exec_call_test_() ->
    {setup,
     fun() ->
        application:start(ppool),
         %% code:load_abs("test/workers/erl_worker"),

          ppool:start_pool(ppool, {p1_async, 3, {?WORKER, start_link, []} }),
          ppool:start_pool(ppool, {p2_async, 3, {?WORKER, start_link, []} }),
          ppool:start_pool(ppool, {p3_async, 3, {?WORKER, start_link, []} }),
          ppool:start_pool(ppool, {p4_async, 1, {?WORKER, start_link, []} }),
          ppool:start_pool(ppool, {p5_async, 1, {?WORKER, start_link, []} })
 

     end,
     fun(_) ->

       ppool:stop_pool(ppool, p1_async),
       ppool:stop_pool(ppool, p2_async),
       ppool:stop_pool(ppool, p3_async),
       ppool:stop_pool(ppool, p4_async),
       ppool:stop_pool(ppool, p5_async),

        application:stop(ppool)

     end,
     {
      foreach,
      fun() ->

         P1=ppool_worker:start_all_workers(p1_async, ?MOD1),
          ?assert(P1=={ok, full_limit}),

         P2=ppool_worker:start_all_workers(p2_async, ?MOD2),

          ?assert(P2=={ok, full_limit}),

         P3=ppool_worker:start_all_workers(p3_async, ?MOD3),

          ?assert(P3=={ok, full_limit}),

         P4=ppool_worker:start_all_workers(p4_async, ?MOD1),
          ?assert(P4=={ok, full_limit}),

         P5=ppool_worker:start_all_workers(p5_async, ?MOD2),

          ?assert(P5=={ok, full_limit}),

          timer:sleep(400)

      end,
      fun(_) ->

         P1=ppool_worker:stop_all_workers(p1_async),
          ?assert(P1==ok),

         P2=ppool_worker:stop_all_workers(p2_async),
          ?assert(P2==ok),

         P3=ppool_worker:stop_all_workers(p3_async),
          ?assert(P3==ok),

         P4=ppool_worker:stop_all_workers(p4_async),
          ?assert(P4==ok),

          timer:sleep(400)



      end,
      run_tests()

     }
    }.


run_tests() ->
    [
     {"call_worker 1 msg",
        fun() ->

            R=ppool_worker:dacast_worker(p1_async, no, <<"request\n">>),

              ?assert(R=:=ok)

        end
     },

     {"call_worker 1 and 10 msg",
      {timeout, 30,
        fun() ->

            R=ppool_worker:dacast_worker(p2_async, no, <<"request1\n">>),

              ?assert(R=:=ok),

              timer:sleep(50),

               Res=sys:get_status(whereis(p2_async)),

              {_,_,_,[_,_,_,_,[_,_,{_,[{_,{_,_,_,_,PidMaps,_,_,_}}]}]]} = Res,

              %% ?debugFmt("process state..~p~n", [PidMaps]),

                Free=maps:keys(maps:filter(fun(_K, V) -> V=:=3 end ,PidMaps)),

              ?assert(length(Free)=:=1),

              ppool_worker:dacast_worker(p2_async, no, <<"request2\n">>),
               timer:sleep(10),

              ppool_worker:dacast_worker(p2_async, no, <<"request3\n">>),
               timer:sleep(10),

              ppool_worker:dacast_worker(p2_async, no, <<"request4\n">>),
                timer:sleep(10),

              R2=ppool_worker:dacast_worker(p2_async, no, <<"request5\n">>),

             % ?debugFmt("start worker..~p~n", [R2]),
 
              ?assert(R2=:=ok),

               timer:sleep(100),

               Res2=sys:get_status(whereis(p2_async)),

            % ?debugFmt("process state..~p~n", [Res2]),

              {_,_,_,[_,_,_,_,[_,_,{_,[{_,{_,_,_,_,PidMaps2,_,Nomore,_}}]}]]} = Res2,

              %% ?debugFmt("process state..~p~n", [PidMaps2]),

                Free2=maps:keys(maps:filter(fun(_K, V) -> V>2 end ,PidMaps2)),

              ?assert(length(Free2)=:=3),
              ?assert(Nomore=:=0),

            timer:sleep(750),

               Res3=sys:get_status(whereis(p2_async)),

              {_,_,_,[_,_,_,_,[_,_,{_,[{_,{_,_,_,_,PidMaps3,_,_,_}}]}]]} = Res3,


              %%?debugFmt("process state..~p~n", [PidMaps3]),

                Free3=maps:keys(maps:filter(fun(_K, V) -> V=:=2 end ,PidMaps3)),

              ?assert(length(Free3)=:=3)

        end
     }},

     {"call_worker 1 and get result",
      {timeout, 5,
        fun() ->

            R=ppool_worker:dacast_worker(p5_async, no, <<"request1\n">>),

              ?assert(R=:=ok),

            timer:sleep(10),

            Arr = ets:tab2list(p5_async),

              [{worker_stat,ID,
                            no,_,p5_async,_,_,
                            _,
                            _,
                            _}] = lists:filter(fun(I)-> case I of 
                                                            {_,_,_,_,_,<<"request1\n">>,_,_,_,_} -> true; 
                                                            _ -> false 
                                                        end 
                                               end, Arr), 


              %% ?debugFmt("process state..~p~n", [ID]),

              Res = ppool_worker:get_result_worker(p5_async, ID),

              {ok,[{worker_stat,
                        ID,
                        _,_,p5_async,_,Status, Response,
                        _,
                        undefined}]} = Res,

              %% ?debugFmt("process state..~p~n", [Res]),

              ?assert(Status=:=running),
              ?assert(Response=:=undefined),

            timer:sleep(300),


              Res2 = ppool_worker:get_result_worker(p5_async, ID),

              {ok,[{worker_stat,
                        ID,
                        _,_,p5_async,_,Status2, Response2,
                        _,
                        _}]} = Res2,

              %% ?debugFmt("process state..~p~n", [Res2]),

              ?assert(Status2=:=ok),
              ?assert(Response2=:=[<<"ok">>])

        end
     }},

     {"call_worker 1 + timeout and get result",
      {timeout, 10,
        fun() ->

            spawn(fun() -> ppool_worker:dacast_worker(p3_async, no, <<"request1\n">>) end),

           timer:sleep(100),

            Arr = ets:tab2list(p3_async),

              %% ?debugFmt("process state..~p~n", [Arr]),

              [{worker_stat,_,
                            _,_,p3_async,_,R,
                            _,
                            _,
                            _}] = lists:filter(fun(I)-> case I of 
                                                            {_,_,_,_,_,<<"request1\n">>,_,_,_,_} -> true; 
                                                            _ -> false 
                                                        end 
                                               end, Arr), 


              %% ?debugFmt("process state..~p~n", [R]),

              ?assert(R=:=running),

            timer:sleep(500),

               Res3=sys:get_status(whereis(p3_async)),

              {_,_,_,[_,_,_,_,[_,_,{_,[{_,{_,_,_,_,PidMaps3,_,_,_}}]}]]} = Res3,

              %% ?debugFmt("process state..~p~n", [PidMaps3]),

                Free3=maps:keys(maps:filter(fun(_K, V) -> V=:=2 end ,PidMaps3)),

              ?assert(length(Free3)=:=3)

        end
     }},

     {"call_worker 1 + error and get result",
      {timeout, 5,
        fun() ->

            spawn(fun() -> ppool_worker:dacast_worker(p4_async, no, <<"error\n">>) end),

           timer:sleep(100),


            Arr = ets:tab2list(p4_async),

              %% ?debugFmt("process state..~p~n", [Arr]),

              [{worker_stat,_,
                            _,_,p4_async,_,R,
                            _,
                            _,
                            _}] = lists:filter(fun(I)-> case I of 
                                                            {_,_,_,_,_,<<"error\n">>,_,_,_,_} -> true; 
                                                            _ -> false 
                                                        end 
                                               end, Arr), 


              %% ?debugFmt("process state..~p~n", [R]),

              ?assert(R=:=error),

              timer:sleep(500),

               Res3=sys:get_status(whereis(p4_async)),

              {_,_,_,[_,_,_,_,[_,_,{_,[{_,{_,_,_,_,PidMaps3,_,_,_}}]}]]} = Res3,

              %% ?debugFmt("process state..~p~n", [PidMaps3]),

              Free3=maps:keys(maps:filter(fun(_K, V) -> V=:=2 end ,PidMaps3)),

              ?assert(length(Free3)=:=1)

        end
     }}

    ].


