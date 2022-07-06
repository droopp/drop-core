-module(ppool_port_worker_async_test).
-include_lib("eunit/include/eunit.hrl").

-define(WORKER, port_worker).
-define(MOD, {"./test/workers/port_worker_async 1 0 2>/dev/null", 3000}).



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

         {R, _}=ppool:start_pool(ppool, {p1_async, 10, {?WORKER, start_link, []} }),
          ?assert(R==ok)

      end,
      fun(_) ->

         R=ppool:stop_pool(ppool, p1_async),
           ?assert(R==ok)
 

      end,
      run_tests()

     }
    }.



run_tests() ->
    [
     {"start one worker",
        fun() ->

            P1=ppool_worker:start_worker(p1_async, ?MOD),
              %% ?debugFmt("start worker..~p~n", [P1]),
                ?assert(is_pid(P1))

        end
     },

     {"start 9 workers",
        fun() ->

          [ppool_worker:start_worker(p1_async, ?MOD)||_X<-[1,2,3,4,5,6,7,8]],

            P1=ppool_worker:start_worker(p1_async, ?MOD),
                ?assert(is_pid(P1))

        end
     },

     {"start 11 overflow workers",
        fun() ->

          [ppool_worker:start_worker(p1_async, ?MOD)||_X<-[1,2,3,4,5,6,7,8,9,10]],

            P1=ppool_worker:start_worker(p1_async, ?MOD),
                ?assert(P1=:=full_limit)

        end
     },


     {"check pid registered",
        fun() ->

            _=ppool_worker:start_worker(p1_async, ?MOD),

               Res=sys:get_status(whereis(p1_async)),

                {_,_,_,[_,_,_,_,[_,_,{_,[{_,{_,_,_,_,PidMaps,_,_,_}}]}]]} = Res,

                ?assert(1=:=length(maps:keys(PidMaps))),

             %% create new
             _=ppool_worker:start_worker(p1_async, ?MOD),
 
               Res2=sys:get_status(whereis(p1_async)),

                {_,_,_,[_,_,_,_,[_,_,{_,[{_,{_,_,_,_,PidMaps2,_,_,_}}]}]]} = Res2,

                ?assert(2=:=length(maps:keys(PidMaps2)))

        end
     },

     {"check pid REregistered",
        fun() ->

            P1=ppool_worker:start_worker(p1_async, ?MOD),

               Res=sys:get_status(whereis(p1_async)),

                {_,_,_,[_,_,_,_,[_,_,{_,[{_,{_,_,_,_,PidMaps,_,_,_}}]}]]} = Res,

                ?assert(maps:keys(PidMaps)=:=[P1]),


            %% kill process and deregister pid 
            exit(P1, kill),

            timer:sleep(50),

               Res2=sys:get_status(whereis(p1_async)),

                ?debugFmt("process state..~p~n", [Res2]),

                {_,_,_,[_,_,_,_,[_,_,{_,[{_,{_,_,_,_,PidMaps2,_,_,_}}]}]]} = Res2,

                ?assert(maps:keys(PidMaps2)=/=[P1])

        end
     },

     {"check start all",
        fun() ->

            P1=ppool_worker:start_all_workers(p1_async, ?MOD),

                ?assert(P1=:={ok, full_limit}),

               Res2=sys:get_status(whereis(p1_async)),

                %% ?debugFmt("process state..~p~n", [Res2]),

                {_,_,_,[_,_,_,_,[_,_,{_,[{_,{_,_,_,_,PidMaps2,_,_,_}}]}]]} = Res2,


                ?assert(10=:=length(maps:keys(PidMaps2)))


        end
     },


     {"check start all >10",
        fun() ->

            P1=ppool_worker:start_all_workers(p1_async, ?MOD, 13),

                ?assert(P1=:={ok, full_limit}),

               Res2=sys:get_status(whereis(p1_async)),

                %% ?debugFmt("process state..~p~n", [Res2]),

                {_,_,_,[_,_,_,_,[_,_,{_,[{_,{_,_,_,_,PidMaps2,_,_,_}}]}]]} = Res2,


                ?assert(13=:=length(maps:keys(PidMaps2)))


        end
     },


     {"check start all  + >10",
        fun() ->

            P1=ppool_worker:start_all_workers(p1_async, ?MOD),

                ?assert(P1=:={ok, full_limit}),

               Res1=sys:get_status(whereis(p1_async)),

                {_,_,_,[_,_,_,_,[_,_,{_,[{_,{_,_,_,_,PidMaps1,_,_,_}}]}]]} = Res1,


                ?assert(10=:=length(maps:keys(PidMaps1))),


            P2=ppool_worker:start_all_workers(p1_async, ?MOD, 14),

                ?assert(P2=:={ok, full_limit}),

               Res2=sys:get_status(whereis(p1_async)),

                {_,_,_,[_,_,_,_,[_,_,{_,[{_,{_,_,_,_,PidMaps2,_,_,_}}]}]]} = Res2,


                ?assert(14=:=length(maps:keys(PidMaps2)))


        end
     },

     {"check start all < 10",
        fun() ->

            P1=ppool_worker:start_all_workers(p1_async, ?MOD, 5),

                ?assert(P1=:={ok, full_limit}),

               Res1=sys:get_status(whereis(p1_async)),

                {_,_,_,[_,_,_,_,[_,_,{_,[{_,{_,_,_,_,PidMaps1,_,_,_}}]}]]} = Res1,

                ?assert(5=:=length(maps:keys(PidMaps1)))

        end
     },

     {"check start all  minus count",
        fun() ->

            P1=ppool_worker:start_all_workers(p1_async, ?MOD, -2),

                ?assert(P1=:={ok, full_limit}),

               Res1=sys:get_status(whereis(p1_async)),

                {_,_,_,[_,_,_,_,[_,_,{_,[{_,{_,_,_,_,PidMaps1,_,_,_}}]}]]} = Res1,

                ?assert(0=:=length(maps:keys(PidMaps1)))

        end
     },

     {"check stop all",
        fun() ->

            P1=ppool_worker:start_all_workers(p1_async, ?MOD),

                ?assert(P1=:={ok, full_limit}),

            ok=ppool_worker:stop_all_workers(p1_async),

             timer:sleep(50),

               Res2=sys:get_status(whereis(p1_async)),

              ?debugFmt("process state..~p~n", [Res2]),
 

                {_,_,_,[_,_,_,_,[_,_,{_,[{_,{_,_,_,_,PidMaps2,_,_,_}}]}]]} = Res2,

                ?assert(0=:=length(maps:keys(PidMaps2)))

        end
     }

 
    ].


run_tests2() ->
    [
     {"start one worker",
        fun() ->

            P1=ppool_worker:start_worker(p1_async, ?MOD),
              %% ?debugFmt("start worker..~p~n", [P1]),
                ?assert(is_pid(P1))

        end
     },

     {"start 9 workers",
        fun() ->

          [ppool_worker:start_worker(p1_async, ?MOD)||_X<-[1,2,3,4,5,6,7,8]],

            P1=ppool_worker:start_worker(p1_async, ?MOD),
                ?assert(is_pid(P1))

        end
     },

     {"start 11 overflow workers",
        fun() ->

          [ppool_worker:start_worker(p1_async, ?MOD)||_X<-[1,2,3,4,5,6,7,8,9,10]],

            P1=ppool_worker:start_worker(p1_async, ?MOD),
                ?assert(P1=:=full_limit)

        end
     },


     {"check pid registered",
        fun() ->

            _=ppool_worker:start_worker(p1_async, ?MOD),

               Res=sys:get_status(whereis(p1_async)),

                {_,_,_,[_,_,_,_,[_,_,{_,[{_,{_,_,_,_,PidMaps,_,_,_}}]}]]} = Res,

                ?assert(1=:=length(maps:keys(PidMaps))),

             %% create new
             _=ppool_worker:start_worker(p1_async, ?MOD),
 
               Res2=sys:get_status(whereis(p1_async)),

                {_,_,_,[_,_,_,_,[_,_,{_,[{_,{_,_,_,_,PidMaps2,_,_,_}}]}]]} = Res2,

                ?assert(2=:=length(maps:keys(PidMaps2)))

        end
     },

     {"check pid REregistered",
        fun() ->

            P1=ppool_worker:start_worker(p1_async, ?MOD),

               Res=sys:get_status(whereis(p1_async)),

                {_,_,_,[_,_,_,_,[_,_,{_,[{_,{_,_,_,_,PidMaps,_,_,_}}]}]]} = Res,

                ?assert(maps:keys(PidMaps)=:=[P1]),


            %% kill process and deregister pid 
            exit(P1, kill),

            timer:sleep(50),

               Res2=sys:get_status(whereis(p1_async)),

                ?debugFmt("process state..~p~n", [Res2]),

                {_,_,_,[_,_,_,_,[_,_,{_,[{_,{_,_,_,_,PidMaps2,_,_,_}}]}]]} = Res2,

                ?assert(maps:keys(PidMaps2)=/=[P1])

        end
     },

     {"check start all",
        fun() ->

            P1=ppool_worker:start_all_workers(p1_async, ?MOD),

                ?assert(P1=:={ok, full_limit}),

               Res2=sys:get_status(whereis(p1_async)),

                %% ?debugFmt("process state..~p~n", [Res2]),

                {_,_,_,[_,_,_,_,[_,_,{_,[{_,{_,_,_,_,PidMaps2,_,_,_}}]}]]} = Res2,


                ?assert(10=:=length(maps:keys(PidMaps2)))


        end
     },


     {"check start all >10",
        fun() ->

            P1=ppool_worker:start_all_workers(p1_async, ?MOD, 13),

                ?assert(P1=:={ok, full_limit}),

               Res2=sys:get_status(whereis(p1_async)),

                %% ?debugFmt("process state..~p~n", [Res2]),

                {_,_,_,[_,_,_,_,[_,_,{_,[{_,{_,_,_,_,PidMaps2,_,_,_}}]}]]} = Res2,


                ?assert(13=:=length(maps:keys(PidMaps2)))


        end
     },


     {"check start all  + >10",
        fun() ->

            P1=ppool_worker:start_all_workers(p1_async, ?MOD),

                ?assert(P1=:={ok, full_limit}),

               Res1=sys:get_status(whereis(p1_async)),

                {_,_,_,[_,_,_,_,[_,_,{_,[{_,{_,_,_,_,PidMaps1,_,_,_}}]}]]} = Res1,


                ?assert(10=:=length(maps:keys(PidMaps1))),


            P2=ppool_worker:start_all_workers(p1_async, ?MOD, 14),

                ?assert(P2=:={ok, full_limit}),

               Res2=sys:get_status(whereis(p1_async)),

                {_,_,_,[_,_,_,_,[_,_,{_,[{_,{_,_,_,_,PidMaps2,_,_,_}}]}]]} = Res2,


                ?assert(14=:=length(maps:keys(PidMaps2)))


        end
     },

     {"check start all < 10",
        fun() ->

            P1=ppool_worker:start_all_workers(p1_async, ?MOD, 5),

                ?assert(P1=:={ok, full_limit}),

               Res1=sys:get_status(whereis(p1_async)),

                {_,_,_,[_,_,_,_,[_,_,{_,[{_,{_,_,_,_,PidMaps1,_,_,_}}]}]]} = Res1,

                ?assert(5=:=length(maps:keys(PidMaps1)))

        end
     },

     {"check start all  minus count",
        fun() ->

            P1=ppool_worker:start_all_workers(p1_async, ?MOD, -2),

                ?assert(P1=:={ok, full_limit}),

               Res1=sys:get_status(whereis(p1_async)),

                {_,_,_,[_,_,_,_,[_,_,{_,[{_,{_,_,_,_,PidMaps1,_,_,_}}]}]]} = Res1,

                ?assert(0=:=length(maps:keys(PidMaps1)))

        end
     },




     {"check stop all",
        fun() ->

            P1=ppool_worker:start_all_workers(p1_async, ?MOD),

                ?assert(P1=:={ok, full_limit}),

            ok=ppool_worker:stop_all_workers(p1_async),

             timer:sleep(50),

               Res2=sys:get_status(whereis(p1_async)),


                {_,_,_,[_,_,_,_,[_,_,{_,[{_,{_,_,_,_,PidMaps2,_,_,_}}]}]]} = Res2,

                ?assert(0=:=length(maps:keys(PidMaps2)))

        end
     },

     {"check stop 8 of 10",
        fun() ->

            P1=ppool_worker:start_all_workers(p1_async, ?MOD),

            ?assert(P1=:={ok, full_limit}),

            ok=ppool_worker:stop_all_workers(p1_async, 2),

             timer:sleep(50),

               Res2=sys:get_status(whereis(p1_async)),

                %% ?debugFmt("process state..~p~n", [Res2]),

                {_,_,_,[_,_,_,_,[_,_,{_,[{_,{_,_,_,_,Pidmaps2,_,_,_}}]}]]} = Res2,

                ?assert(2=:=length(maps:keys(Pidmaps2)))

        end
     },

     {"check 2 stops: 10 -> 4 -> 2",
        fun() ->

            P1=ppool_worker:start_all_workers(p1_async, ?MOD),

                ?assert(P1=:={ok, full_limit}),

            ok=ppool_worker:stop_all_workers(p1_async, 4),

             timer:sleep(50),

               Res=sys:get_status(whereis(p1_async)),

                {_,_,_,[_,_,_,_,[_,_,{_,[{_,{_,_,_,_,Pidmaps,_,_,_}}]}]]} = Res,

                ?assert(4=:=length(maps:keys(Pidmaps))),


            ok=ppool_worker:stop_all_workers(p1_async, 2),

             timer:sleep(50),

               Res2=sys:get_status(whereis(p1_async)),

                {_,_,_,[_,_,_,_,[_,_,{_,[{_,{_,_,_,_,Pidmaps2,_,_,_}}]}]]} = Res2,

                ?assert(2=:=length(maps:keys(Pidmaps2)))

        end
     },

     {"start 3 -> stops: all -> start all",
        fun() ->

          [ppool_worker:start_worker(p1_async, ?MOD)||_X<-[1,2,3]],

             timer:sleep(50),

               Res=sys:get_status(whereis(p1_async)),

                {_,_,_,[_,_,_,_,[_,_,{_,[{_,{_,_,_,_,Pidmaps,_,_,_}}]}]]} = Res,

                ?assert(3=:=length(maps:keys(Pidmaps))),

            ok=ppool_worker:stop_all_workers(p1_async),

             timer:sleep(50),

               Res2=sys:get_status(whereis(p1_async)),

                {_,_,_,[_,_,_,_,[_,_,{_,[{_,{_,_,_,_,Pidmaps2,_,_,_}}]}]]} = Res2,

                ?assert(0=:=length(maps:keys(Pidmaps2))),


            P2=ppool_worker:start_all_workers(p1_async, ?MOD),

                ?assert(P2=:={ok, full_limit}),

             timer:sleep(50),

               Res3=sys:get_status(whereis(p1_async)),

                {_,_,_,[_,_,_,_,[_,_,{_,[{_,{_,_,_,_,Pidmaps3,_,_,_}}]}]]} = Res3,

                ?assert(10=:=length(maps:keys(Pidmaps3)))

        end
     },

     {"double stop",
        fun() ->

            P1=ppool_worker:start_all_workers(p1_async, ?MOD),

                ?assert(P1=:={ok, full_limit}),

            ok=ppool_worker:stop_all_workers(p1_async, 4),
            ok=ppool_worker:stop_all_workers(p1_async, 4),


             timer:sleep(50),

               Res=sys:get_status(whereis(p1_async)),

                {_,_,_,[_,_,_,_,[_,_,{_,[{_,{_,_,_,_,Pidmaps,_,_,_}}]}]]} = Res,

                ?assert(4=:=length(maps:keys(Pidmaps))),


            ok=ppool_worker:stop_all_workers(p1_async),
            ok=ppool_worker:stop_all_workers(p1_async),

             timer:sleep(50),

               Res2=sys:get_status(whereis(p1_async)),

                {_,_,_,[_,_,_,_,[_,_,{_,[{_,{_,_,_,_,Pidmaps2,_,_,_}}]}]]} = Res2,

                ?assert(0=:=length(maps:keys(Pidmaps2)))

        end
     },

     {"cap workers",
        fun() ->

            ppool_worker:cap_workers(p1_async, ?MOD, 3),

             timer:sleep(50),

               Res=sys:get_status(whereis(p1_async)),

                {_,_,_,[_,_,_,_,[_,_,{_,[{_,{_,_,_,_,Pidmaps,_,_,_}}]}]]} = Res,

                ?assert(3=:=length(maps:keys(Pidmaps))),


            ppool_worker:cap_workers(p1_async, ?MOD, 10),

             timer:sleep(50),

               Res2=sys:get_status(whereis(p1_async)),

                {_,_,_,[_,_,_,_,[_,_,{_,[{_,{_,_,_,_,Pidmaps2,_,_,_}}]}]]} = Res2,

                ?assert(10=:=length(maps:keys(Pidmaps2))),


            ppool_worker:cap_workers(p1_async, ?MOD, 2),

             timer:sleep(50),

               Res3=sys:get_status(whereis(p1_async)),

                {_,_,_,[_,_,_,_,[_,_,{_,[{_,{_,_,_,_,Pidmaps3,_,_,_}}]}]]} = Res3,

                ?assert(2=:=length(maps:keys(Pidmaps3)))


        end
     }


    ].


