-module(ppool_worker_call_test).
-include_lib("eunit/include/eunit.hrl").

exec_test_() ->
    {setup,
     fun() ->
        application:start(ppool),
         %% code:load_abs("test/workers/erl_worker"),
          ppool:start_pool(ppool, {p1, 3, {worker, start_link, []} }),
          ppool:start_pool(ppool, {p2, 3, {worker, start_link, []} }),
          ppool:start_pool(ppool, {p3, 3, {worker, start_link, []} })

     end,
     fun(_) ->

       ppool:stop_pool(ppool, p1),
       ppool:stop_pool(ppool, p2),
       ppool:stop_pool(ppool, p3),

        application:stop(ppool)

     end,
     {
      foreach,
      fun() ->

         P1=ppool_worker:start_all_workers(p1, {{erl_worker, do_ok}, 1000}),
          ?assert(P1=={ok, full_limit}),

         P2=ppool_worker:start_all_workers(p2, {{erl_worker, do_2000_ok}, 3000}),

          ?assert(P2=={ok, full_limit}),

         P3=ppool_worker:start_all_workers(p3, {{erl_worker, do_2000_ok}, 1000}),

          ?assert(P3=={ok, full_limit})

      end,
      fun(_) ->

         P1=ppool_worker:stop_all_workers(p1),
          ?assert(P1==ok),

         P2=ppool_worker:stop_all_workers(p2),
          ?assert(P2==ok),

         P3=ppool_worker:stop_all_workers(p3),
          ?assert(P3==ok)

      end,
      run_tests()

     }
    }.


run_tests() ->
    [
     {"call_worker 1 msg",
        fun() ->

            {R, _}=ppool_worker:call_worker(p1, <<"request\n">>),

              ?assert(R=:=ok)

        end
     },

     {"call_worker 1 and 10 msg",
      {timeout, 30,
        fun() ->

            {R, _}=ppool_worker:call_worker(p2, <<"request1\n">>),

              ?assert(R=:=ok),

               Res=sys:get_status(whereis(p2)),

              {_,_,_,[_,_,_,_,[_,_,{_,[{_,{_,_,_,_,PidMaps,_,_,_}}]}]]} = Res,

                % ?debugFmt("process state..~p~n", [PidMaps]),

                Free=maps:keys(maps:filter(fun(_K, V) -> V=:=2 end ,PidMaps)),

              ?assert(length(Free)=:=1),

             [ppool_worker:call_worker(p2, <<"request10\n">>) ||_X<-[1,2,3,4,5,6,7,8,9]],

              R2=ppool_worker:call_worker(p2, <<"request2\n">>),

             % ?debugFmt("start worker..~p~n", [R2]),
 
              ?assert(R2=:={ok, []}),


               Res2=sys:get_status(whereis(p2)),

              {_,_,_,[_,_,_,_,[_,_,{_,[{_,{_,_,_,_,PidMaps2,_,_,_}}]}]]} = Res2,

              % ?debugFmt("process state..~p~n", [PidMaps2]),

                Free2=maps:keys(maps:filter(fun(_K, V) -> V=:=2 end ,PidMaps2)),

              ?assert(length(Free2)=:=3),

            timer:sleep(3000),

               Res3=sys:get_status(whereis(p2)),

              {_,_,_,[_,_,_,_,[_,_,{_,[{_,{_,_,_,_,PidMaps3,_,_,_}}]}]]} = Res3,

              %%?debugFmt("process state..~p~n", [PidMaps3]),

                Free3=maps:keys(maps:filter(fun(_K, V) -> V=:=2 end ,PidMaps3)),

              ?assert(length(Free3)=:=0)

        end
     }},

     {"call_worker 1 and get result",
      {timeout, 5,
        fun() ->

            {R, ID}=ppool_worker:call_worker(p2, <<"request1\n">>),

              ?assert(R=:=ok),

              Res = ppool_worker:get_result_worker(p2, ID),

              {ok,[{worker_stat,
                        ID,
                        no,_,p2,no,Status, Response,
                        _,
                        undefined}]} = Res,

              %% ?debugFmt("process state..~p~n", [Res]),

              ?assert(Status=:=running),
              ?assert(Response=:=undefined),

            timer:sleep(3000),


              Res2 = ppool_worker:get_result_worker(p2, ID),

              {ok,[{worker_stat,
                        ID,
                        no,_,p2,no,Status2, Response2,
                        _,
                        _}]} = Res2,

              %%?debugFmt("process state..~p~n", [Res2]),


              ?assert(Status2=:=ok),
              ?assert(Response2=:=no)

        end
     }},

     {"call_worker 1 + timeout and get result",
      {timeout, 10,
        fun() ->

            {R, ID}=ppool_worker:call_worker(p3, <<"request1\n">>),

              ?assert(R=:=ok),

           timer:sleep(3000),


              Res2 = ppool_worker:get_result_worker(p2, ID),

              {ok,[{worker_stat,
                        ID,
                        no,_,p2,no,Status2, Response2,
                        _,
                        _}]} = Res2,

              %%?debugFmt("process state..~p~n", [Res2]),


              ?assert(Status2=:=ok),
              ?assert(Response2=:=no)

        end
     }}









    ].

