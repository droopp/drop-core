-module(ppool_worker_test).
-include_lib("eunit/include/eunit.hrl").

exec_test_() ->
    {setup,
     fun() ->
        application:start(ppool),
        code:load_abs("test/workers/erl_worker")
   
     end,
     fun(_) ->

        application:stop(ppool)

     end,
     {
      foreach,
      fun() ->

         {R, _}=ppool:start_pool(ppool, {p1, 10, {worker, start_link, []} }),
          ?assert(R==ok)

      end,
      fun(_) ->

         R=ppool:stop_pool(ppool, p1),
           ?assert(R==ok)
 

      end,
      run_tests()

     }
    }.


run_tests() ->
    [
     {"start one worker",
        fun() ->

            P1=ppool_worker:start_worker(p1, {{erl_worker, do_5000_ok}, 6000}),
              ?debugFmt("start worker..~p~n", [P1]),
                ?assert(is_pid(P1))

        end
     },

     {"start 9 workers",
        fun() ->

          [ppool_worker:start_worker(p1, {{erl_worker, do_5000_ok}, 6000})||_X<-[1,2,3,4,5,6,7,8]],

            P1=ppool_worker:start_worker(p1, {{erl_worker, do_5000_ok}, 6000}),
              ?debugFmt("start worker..~p~n", [P1]),
                ?assert(is_pid(P1))

        end
     },

     {"start 11 overflow workers",
        fun() ->

          [ppool_worker:start_worker(p1, {{erl_worker, do_5000_ok}, 6000})||_X<-[1,2,3,4,5,6,7,8,9,10]],

            P1=ppool_worker:start_worker(p1, {{erl_worker, do_5000_ok}, 6000}),
              ?debugFmt("start worker..~p~n", [P1]),
                ?assert(P1=:=full_limit)

        end
     },


     {"check pid registered",
        fun() ->

            P1=ppool_worker:start_worker(p1, {{erl_worker, do_5000_ok}, 6000}),
             ?debugFmt("start worker..~p~n", [P1]),

               Res=sys:get_status(whereis(p1)),

                {_,_,_,[_,_,_,_,[_,_,{_,[{_,{_,_,_,_,PidMaps,_,_,_}}]}]]} = Res,


                ?assert(PidMaps=:=#{P1 => 0}),

             %% create new
             P2=ppool_worker:start_worker(p1, {{erl_worker, do_5000_ok}, 6000}),
 
               Res2=sys:get_status(whereis(p1)),

                {_,_,_,[_,_,_,_,[_,_,{_,[{_,{_,_,_,_,PidMaps2,_,_,_}}]}]]} = Res2,


                ?assert(PidMaps2=:=#{P1 => 0, P2 => 0})


        end
     },

     {"check pid DEregistered",
        fun() ->

            P1=ppool_worker:start_worker(p1, {{erl_worker, do_5000_ok}, 6000}),
             ?debugFmt("start worker..~p~n", [P1]),

               Res=sys:get_status(whereis(p1)),

                {_,_,_,[_,_,_,_,[_,_,{_,[{_,{_,_,_,_,PidMaps,_,_,_}}]}]]} = Res,


                ?assert(PidMaps=:=#{P1 => 0}),


            %% kill process and deregister pid 
            exit(P1, kill),
            timer:sleep(50),

               Res2=sys:get_status(whereis(p1)),

                %% ?debugFmt("process state..~p~n", [Res2]),

                {_,_,_,[_,_,_,_,[_,_,{_,[{_,{_,_,_,_,PidMaps2,_,_,_}}]}]]} = Res2,


                ?assert(PidMaps2=/=#{P1 => 0})

        end
     },

     {"check start all",
        fun() ->

            P1=ppool_worker:start_all_workers(p1, {{erl_worker, do_5000_ok}, 6000}),

                ?assert(P1=:={ok, full_limit})


        end
     }












    ].

